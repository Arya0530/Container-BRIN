
import os
import json
import time
from uuid import UUID
from pathlib import Path
from datetime import datetime, timezone

import clickhouse_connect
import psycopg
from dotenv import load_dotenv


# Load project configuration.
ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

WORKER_NAME = "container_telemetry_worker"
BATCH_SIZE = 100
POLL_INTERVAL = 3



# Connect to ClickHouse using the configured hostname.
clickhouse = clickhouse_connect.get_client(
    host=os.getenv("CLICKHOUSE_HOST", "127.0.0.1"),
    port=8123,
    username=os.environ["CLICKHOUSE_USER"],
    password=os.environ["CLICKHOUSE_PASSWORD"],
    database="container_monitoring_raw"
)



def validate_payload(payload):
    # Validate the required telemetry fields.
    if not isinstance(payload, dict):
        raise ValueError("Payload must be a JSON object")

    device_id = payload["deviceID"]
    counter = payload["packetCounter"]
    gps = payload["gps"]
    door = payload["door"]

    if not isinstance(device_id, str) or not device_id:
        raise ValueError("Invalid device ID")

    if type(counter) is not int or counter < 0:
        raise ValueError("Invalid packet counter")

    if not isinstance(gps, dict):
        raise ValueError("Invalid GPS object")

    lat = gps["lat"]
    lon = gps["lon"]

    if (
        type(lat) not in (int, float)
        or type(lon) not in (int, float)
        or not -90 <= lat <= 90
        or not -180 <= lon <= 180
    ):
        raise ValueError("Invalid GPS coordinates")

    if door not in ("OPEN", "CLOSED"):
        raise ValueError("Invalid door status")

    device_time = gps["timeUTC"]

    if not isinstance(device_time, str):
        raise ValueError("Invalid device timestamp")

    recorded_at = datetime.fromisoformat(
        device_time.replace("Z", "+00:00")
    )

    if recorded_at.tzinfo is None:
        raise ValueError("Device timestamp requires a timezone")

    return (
        device_id,
        counter,
        gps,
        door,
        recorded_at.astimezone(timezone.utc)
    )


def fetch_raw_batch(cursor_time, cursor_id):
    # Query raw events after the last committed checkpoint.
    timestamp = cursor_time.astimezone(
        timezone.utc
    ).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

    event_id = str(cursor_id or UUID(int=0))

    query = f"""
        SELECT event_id, received_at, raw_payload
        FROM container_monitoring_raw.raw_telemetry
        WHERE
            received_at > toDateTime64(
                '{timestamp}', 3, 'UTC'
            )
            OR (
                received_at = toDateTime64(
                    '{timestamp}', 3, 'UTC'
                )
                AND event_id > toUUID('{event_id}')
            )
        ORDER BY received_at, event_id
        LIMIT {BATCH_SIZE}
    """

    return clickhouse.query(query).result_rows


def process_event(cursor, event_id, raw_payload):
    # Decode and validate the raw message.
    payload = json.loads(raw_payload)

    device_id, counter, gps, door, recorded_at = (
        validate_payload(payload)
    )

    # Map the hardware ID to a registered container.
    cursor.execute("""
        SELECT container_id
        FROM public.containers
        WHERE device_id = %s
    """, (device_id,))

    container = cursor.fetchone()

    if container is None:
        raise ValueError(f"Unknown device: {device_id}")

    container_id = container[0]

    # Ignore duplicate telemetry using the unique index.
    cursor.execute("""
        INSERT INTO public.telemetry_clean (
            container_id,
            recorded_at,
            latitude,
            longitude,
            altitude,
            speed,
            door_status,
            rssi,
            snr,
            packet_counter
        )
        VALUES (
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s
        )
        ON CONFLICT (
            container_id,
            packet_counter
        )
        WHERE packet_counter IS NOT NULL
        DO NOTHING
    """, (
        container_id,
        recorded_at,
        gps["lat"],
        gps["lon"],
        gps.get("alt"),
        gps.get("speed"),
        door,
        payload.get("rssi"),
        payload.get("snr"),
        counter
    ))

    return "inserted" if cursor.rowcount == 1 else "duplicate"


def process_batch(postgres):
    # Keep the checkpoint and processed records in one transaction.
    with postgres.cursor() as cursor:
        cursor.execute("""
            SELECT last_received_at, last_event_id
            FROM public.preprocessing_checkpoint
            WHERE worker_name = %s
            FOR UPDATE
        """, (WORKER_NAME,))

        checkpoint = cursor.fetchone()

        if checkpoint is None:
            raise RuntimeError("Worker checkpoint was not found")

        rows = fetch_raw_batch(checkpoint[0], checkpoint[1])

        if not rows:
            postgres.commit()
            return 0

        inserted = 0
        duplicates = 0
        rejected = 0

        for event_id, received_at, raw_payload in rows:
            # Use a savepoint so an invalid row cannot abort the batch.
            cursor.execute("SAVEPOINT telemetry_item")

            try:
                result = process_event(
                    cursor, event_id, raw_payload
                )

                if result == "inserted":
                    inserted += 1
                else:
                    duplicates += 1

                cursor.execute("RELEASE SAVEPOINT telemetry_item")

            except (
                ValueError,
                KeyError,
                TypeError,
                json.JSONDecodeError
            ) as error:
                cursor.execute(
                    "ROLLBACK TO SAVEPOINT telemetry_item"
                )
                cursor.execute(
                    "RELEASE SAVEPOINT telemetry_item"
                )

                # Preserve invalid messages for later investigation.
                cursor.execute("""
                    INSERT INTO public.telemetry_rejected (
                        event_id, reason, raw_payload
                    )
                    VALUES (%s, %s, %s)
                    ON CONFLICT (event_id) DO NOTHING
                """, (
                    event_id,
                    str(error),
                    raw_payload
                ))

                rejected += 1

        # Advance only after the entire batch has been handled.
        last_event_id, last_received_at, _ = rows[-1]

        if last_received_at.tzinfo is None:
            last_received_at = last_received_at.replace(
                tzinfo=timezone.utc
            )

        cursor.execute("""
            UPDATE public.preprocessing_checkpoint
            SET
                last_received_at = %s,
                last_event_id = %s,
                updated_at = NOW()
            WHERE worker_name = %s
        """, (
            last_received_at,
            last_event_id,
            WORKER_NAME
        ))

        postgres.commit()

        print(
            f"Batch processed: {len(rows)} | "
            f"Inserted: {inserted} | "
            f"Duplicates: {duplicates} | "
            f"Rejected: {rejected}"
        )

        return len(rows)


def main():
    print("Preprocessing worker started.")
    print(f"Polling ClickHouse every {POLL_INTERVAL} seconds...")

    with psycopg.connect(
        host=os.getenv("POSTGRES_HOST", "127.0.0.1"),
        port=int(os.getenv("POSTGRES_PORT", "55433")),
        dbname="container_monitoring",
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"]
    ) as postgres:

        while True:
            try:
                count = process_batch(postgres)

                # Drain pending batches before sleeping.
                if count < BATCH_SIZE:
                    time.sleep(POLL_INTERVAL)

            except KeyboardInterrupt:
                raise

            except Exception as error:
                postgres.rollback()
                print(f"Worker error: {error}")
                time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nPreprocessing worker stopped.")

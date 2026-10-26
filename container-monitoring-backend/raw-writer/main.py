
import os
import sys
import json
from pathlib import Path

import pika
import clickhouse_connect
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

rabbit_credentials = pika.PlainCredentials(
    os.environ["RABBITMQ_USER"],
    os.environ["RABBITMQ_PASSWORD"]
)

rabbit_connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host=os.getenv("RABBITMQ_HOST", "127.0.0.1"),
        port=5672,
        credentials=rabbit_credentials
    )
)

channel = rabbit_connection.channel()
channel.queue_declare(
    queue="container.telemetry.raw",
    durable=True
)
channel.basic_qos(prefetch_count=1)

clickhouse = clickhouse_connect.get_client(
    host=os.getenv("CLICKHOUSE_HOST", "127.0.0.1"),
    port=8123,
    username=os.environ["CLICKHOUSE_USER"],
    password=os.environ["CLICKHOUSE_PASSWORD"],
    database="container_monitoring_raw"
)

def process_message(ch, method, properties, body):
    try:
        payload = json.loads(body)
        gps = payload.get("gps", {})

# Temporary mapping until the device ID
# is linked to a container series.
        series = payload.get(
            "series",
            payload["deviceID"]
        )

        clickhouse.insert(
            "raw_telemetry",
            [[
                series,
                gps.get("lat"),
                gps.get("lon"),
                gps.get("alt"),
                gps.get("speed"),
                payload.get("door"),
                payload.get("rssi"),
                payload.get("snr"),
                body.decode("utf-8")
            ]],
            column_names=[
                "series",
                "latitude",
                "longitude",
                "altitude",
                "speed",
                "door_status",
                "rssi",
                "snr",
                "raw_payload"
            ]
        )

 # ACK after a successful insert.
        ch.basic_ack(delivery_tag=method.delivery_tag)
        print(f"Data tersimpan: {series}")

    except Exception as error:
        print(f"Gagal memproses pesan: {error}")
        sys.exit(1)

channel.basic_consume(
    queue="container.telemetry.raw",
    on_message_callback=process_message,
    auto_ack=False
)

print("Raw Data Writer berjalan...")
print("Menunggu pesan dari RabbitMQ...")

channel.start_consuming()

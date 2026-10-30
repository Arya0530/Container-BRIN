"""Normalize ESP32 LoRa packets and publish them to RabbitMQ."""

import json
import os
import time
from typing import Any

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    # Standalone normalization tests do not require third-party modules.
    pass

QUEUE = os.getenv("RABBITMQ_QUEUE", "container.telemetry.raw")


def normalize_packet(raw: dict[str, Any]) -> dict[str, Any] | None:
    """Accept original ESP32 JSON or a flattened telemetry record.

    The MAC of the BLE receiver is transport identity; deviceID is the LoRa
    transmitter's identifier and remains the routing key to the container.
    """
    if not isinstance(raw, dict):
        return None
    counter = raw.get("packetCounter", raw.get("packet_counter"))
    dev = raw.get("deviceID", raw.get("device"))
    if counter is None or dev is None:
        # Metadata-only/config events are not telemetry packets.
        return None
    try:
        counter = int(counter)
    except (ValueError, TypeError):
        return None
    gps_in = raw.get("gps")
    gps_in = gps_in if isinstance(gps_in, dict) else {}
    gps = {
        "lat": gps_in.get("lat", raw.get("lat")),
        "lon": gps_in.get("lon", raw.get("lon")),
        "alt": gps_in.get("alt", raw.get("alt")),
        "speed": gps_in.get("speed", raw.get("speed")),
        "sats": gps_in.get("sats", raw.get("sats")),
        "timeUTC": gps_in.get("timeUTC", raw.get("timeUTC")),
    }
    if gps["lat"] is None or gps["lon"] is None:
        return None
    # Keep numeric 746996 as string to match the PostgreSQL device_id field.
    packet = {
        "deviceID": str(dev).strip(),
        "packetCounter": counter,
        "rssi": raw.get("rssi"),
        "snr": raw.get("snr"),
        "door": raw.get("door"),
        "gps": gps,
        "tujuan": raw.get("tujuan", raw.get("tujuanField")),
        "perusahaan": raw.get("perusahaan", raw.get("perusahaanField")),
        "isi": raw.get("isi"),
    }
    if raw.get("receiverMAC"):
        packet["receiverMAC"] = str(raw["receiverMAC"])
    return packet


class RabbitPublisher:
    def __init__(self):
        self.connection = None
        self.channel = None

    def _connect(self):
        import pika
        if self.connection and self.connection.is_open and self.channel and self.channel.is_open:
            return
        user = os.getenv("RABBITMQ_USER", os.getenv("RABBITMQ_USERNAME", "guest"))
        password = os.getenv("RABBITMQ_PASSWORD", "guest")
        params = pika.ConnectionParameters(
            host=os.getenv("RABBITMQ_HOST", "127.0.0.1"),
            port=int(os.getenv("RABBITMQ_PORT", "5672")),
            virtual_host=os.getenv("RABBITMQ_VHOST", "/"),
            credentials=pika.PlainCredentials(user, password),
            heartbeat=30,
            blocked_connection_timeout=30,
        )
        self.connection = pika.BlockingConnection(params)
        self.channel = self.connection.channel()
        self.channel.queue_declare(queue=QUEUE, durable=True)
        self.channel.confirm_delivery()

    def send(self, packet: dict[str, Any]):
        import pika
        body = json.dumps(packet, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        while True:
            try:
                self._connect()
                self.channel.basic_publish(
                    exchange="",
                    routing_key=QUEUE,
                    body=body,
                    properties=pika.BasicProperties(
                        content_type="application/json", delivery_mode=2
                    ),
                    mandatory=True,
                )
                print(f"Published device={packet['deviceID']} packet={packet['packetCounter']}", flush=True)
                return
            except (pika.exceptions.AMQPError, OSError) as exc:
                print(f"RabbitMQ connection failed: {exc}; retry in 3s", flush=True)
                self.channel = None
                self.connection = None
                time.sleep(3)

    def close(self):
        if self.connection and self.connection.is_open:
            self.connection.close()


class JsonStream:
    """Extract JSON objects from newline data or fragmented BLE notifications."""
    def __init__(self):
        self.buffer = ""
        self.decoder = json.JSONDecoder()

    def feed(self, data: str) -> list[dict[str, Any]]:
        self.buffer += data
        if len(self.buffer) > 100_000:
            self.buffer = ""
            raise ValueError("JSON frame too large; buffer discarded")
        found = []
        while True:
            brace = self.buffer.find("{")
            if brace < 0:
                self.buffer = self.buffer[-256:]
                break
            self.buffer = self.buffer[brace:]
            try:
                value, offset = self.decoder.raw_decode(self.buffer)
            except json.JSONDecodeError:
                # The next BLE notification may complete the JSON object.
                # For serial lines, dropping the buffer is handled at the caller.
                break
            self.buffer = self.buffer[offset:]
            if isinstance(value, dict):
                found.append(value)
        return found

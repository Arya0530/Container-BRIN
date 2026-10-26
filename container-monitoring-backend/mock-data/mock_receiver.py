
import os
import json
import time
from pathlib import Path
from datetime import datetime, timezone

import pika
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

credentials = pika.PlainCredentials(
    os.environ["RABBITMQ_USER"],
    os.environ["RABBITMQ_PASSWORD"]
)

connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host="127.0.0.1",
        port=5672,
        credentials=credentials
    )
)

channel = connection.channel()

channel.queue_declare(
    queue="container.telemetry.raw",
    durable=True
)
# Ensure broker confirms publish
channel.confirm_delivery()

try:
    for counter in range(122, 127):
        payload = {
            "deviceID": "STM32-001",
            "packetCounter": counter,
            "gps": {
                "lat": -7.7956,
                "lon": 110.3695,
                "alt": 120.5,
                "speed": 0.0,
                "sats": 8,
                "timeUTC": datetime.now(
                    timezone.utc
                ).isoformat()
            },
            "door": "CLOSED",
            "rssi": -51,
            "snr": 8.7
        }

        channel.basic_publish(
            exchange="",
            routing_key="container.telemetry.raw",
            body=json.dumps(payload),
            properties=pika.BasicProperties(
                delivery_mode=2,
                content_type="application/json"
            ),
            mandatory=True
        )

        print(f"Packet {counter} dikirim")
        time.sleep(2)

finally:
    connection.close()

print("Simulasi selesai.")

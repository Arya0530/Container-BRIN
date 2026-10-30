"""Receive ESP32 telemetry over HTTP and publish persistent RabbitMQ messages."""
import hmac
import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pika
from dotenv import load_dotenv

load_dotenv()

PORT = int(os.getenv("INGEST_PORT", "8090"))
API_KEY = os.getenv("INGEST_API_KEY", "")
RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "127.0.0.1")
RABBITMQ_PORT = int(os.getenv("RABBITMQ_PORT", "5672"))
RABBITMQ_USER = os.getenv("RABBITMQ_USER", "guest")
RABBITMQ_PASSWORD = os.getenv("RABBITMQ_PASSWORD", os.getenv("RABBITMQ_PASS", "guest"))
QUEUE = "container.telemetry.raw"


def publish(payload: dict) -> None:
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    parameters = pika.ConnectionParameters(
        host=RABBITMQ_HOST,
        port=RABBITMQ_PORT,
        credentials=credentials,
        heartbeat=30,
        blocked_connection_timeout=5,
        socket_timeout=5,
    )
    connection = pika.BlockingConnection(parameters)
    try:
        channel = connection.channel()
        channel.queue_declare(queue=QUEUE, durable=True)
        channel.confirm_delivery()
        channel.basic_publish(
            exchange="",
            routing_key=QUEUE,
            body=json.dumps(payload, ensure_ascii=False, allow_nan=False).encode("utf-8"),
            properties=pika.BasicProperties(
                content_type="application/json", delivery_mode=2
            ),
            mandatory=True,
        )
    finally:
        connection.close()


class Handler(BaseHTTPRequestHandler):
    def respond(self, status: int, body: dict) -> None:
        encoded = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self) -> None:
        if self.path == "/health":
            self.respond(200, {"status": "ok", "service": "esp32-ingest-gateway"})
        else:
            self.respond(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/ingest":
            self.respond(404, {"error": "not found"})
            return
        key = self.headers.get("X-Device-Key", "")
        if not hmac.compare_digest(key, API_KEY):
            self.respond(401, {"error": "invalid device key"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.respond(400, {"error": "invalid content length"})
            return
        if length <= 0 or length > 4096:
            self.respond(413, {"error": "body must be between 1 and 4096 bytes"})
            return
        try:
            payload = json.loads(self.rfile.read(length))
            if not isinstance(payload, dict):
                raise ValueError("root JSON must be an object")
            if not isinstance(payload.get("deviceID"), (str, int)):
                raise ValueError("deviceID is required")
            if not isinstance(payload.get("packetCounter"), int):
                raise ValueError("packetCounter must be an integer")
            if not isinstance(payload.get("gps"), dict):
                raise ValueError("gps object is required")
        except (ValueError, UnicodeDecodeError) as exc:
            self.respond(400, {"error": str(exc)})
            return

        # The original GPS time remains available in payload["gps"]["timeUTC"].
        payload["gatewayReceivedAt"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        try:
            publish(payload)
        except Exception as exc:
            print(f"[ERROR] RabbitMQ publish failed: {type(exc).__name__}: {exc}", flush=True)
            self.respond(503, {"error": "RabbitMQ unavailable"})
            return
        print(f"[QUEUED] deviceID={payload['deviceID']} counter={payload['packetCounter']}", flush=True)
        self.respond(202, {"status": "queued"})


if __name__ == "__main__":
    if len(API_KEY) < 16 or API_KEY == "REPLACE_WITH_A_LONG_RANDOM_KEY":
        raise SystemExit("Set a non-placeholder INGEST_API_KEY (16+ chars) in gateway/.env")
    print(f"ESP32 HTTP gateway listening on 0.0.0.0:{PORT}; queue={QUEUE}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()

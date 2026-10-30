"""Bridge the original ESP32's USB serial JSON output to RabbitMQ.

Example: py gateway/serial_gateway.py --port COM5
"""
import argparse
import json
import time

import serial

from common import RabbitPublisher, normalize_packet


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True, help="ESP32 COM port, e.g. COM5")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--dry-run", action="store_true", help="Print packets instead of publishing")
    args = parser.parse_args()
    pub = None if args.dry_run else RabbitPublisher()
    print("Reading ESP32 serial output. Stop with Ctrl+C.", flush=True)
    try:
        while True:
            try:
                with serial.Serial(args.port, args.baud, timeout=1) as port:
                    # ESP32's existing firmware prints diagnostics followed by
                    # a complete one-line JSON object, prefixed by 'JSON:'.
                    while True:
                        line = port.readline().decode("utf-8", errors="replace").strip()
                        if not line.startswith("{"):
                            continue
                        try:
                            raw = json.loads(line)
                        except json.JSONDecodeError:
                            print("Skipped incomplete JSON line", flush=True)
                            continue
                        packet = normalize_packet(raw)
                        if not packet:
                            print("Ignored non-telemetry JSON", flush=True)
                            continue
                        if args.dry_run:
                            print(json.dumps(packet, ensure_ascii=False), flush=True)
                        else:
                            pub.send(packet)
            except serial.SerialException as exc:
                print(f"Serial port unavailable: {exc}; retry in 3s", flush=True)
                time.sleep(3)
    except KeyboardInterrupt:
        print("Stopped.")
    finally:
        if pub:
            pub.close()


if __name__ == "__main__":
    main()

"""BLE JSON notification bridge for new ESP32 firmware.

Discover services first: py gateway/ble_gateway.py --scan
                       py gateway/ble_gateway.py --device <BLE_ADDRESS> --inspect
Then bridge:          py gateway/ble_gateway.py --device <BLE_ADDRESS> --char <UUID>
"""
import argparse
import asyncio
import codecs
import json

from bleak import BleakClient, BleakScanner

from common import JsonStream, RabbitPublisher, normalize_packet


async def scan():
    devices = await BleakScanner.discover(timeout=10)
    for device in devices:
        print(f"{device.address}  {device.name or '(unnamed)'}")


async def run_bridge(args):
    if args.inspect:
        async with BleakClient(args.device, timeout=20) as client:
            for service in client.services:
                print(f"SERVICE {service.uuid}")
                for ch in service.characteristics:
                    print(f"  CHARACTERISTIC {ch.uuid} properties={','.join(ch.properties)}")
        return

    publisher = None if args.dry_run else RabbitPublisher()
    try:
        while True:
            frames = JsonStream()
            utf8 = codecs.getincrementaldecoder("utf-8")("replace")
            incoming = asyncio.Queue()
            try:
                async with BleakClient(args.device, timeout=20) as client:
                    def on_notification(_sender, data: bytearray):
                        incoming.put_nowait(bytes(data))

                    await client.start_notify(args.char, on_notification)
                    print(f"BLE connected: {args.device}; notify={args.char}", flush=True)
                    while client.is_connected:
                        try:
                            fragment = await asyncio.wait_for(incoming.get(), timeout=20)
                        except asyncio.TimeoutError:
                            # Telemetry may arrive minutes apart; inactivity is normal.
                            continue
                        try:
                            messages = frames.feed(utf8.decode(fragment))
                        except ValueError as exc:
                            print(f"Discarded malformed stream: {exc}", flush=True)
                            continue
                        for raw in messages:
                            packet = normalize_packet(raw)
                            if packet is None:
                                print("Ignored JSON without telemetry fields", flush=True)
                                continue
                            if args.dry_run:
                                print(json.dumps(packet, ensure_ascii=False), flush=True)
                            else:
                                publisher.send(packet)
            except Exception as exc:
                # A transient BLE disconnect should not stop the gateway.
                print(f"BLE disconnected/error: {exc}; retrying in 3s", flush=True)
                await asyncio.sleep(3)
    finally:
        if publisher:
            publisher.close()


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scan", action="store_true")
    parser.add_argument("--inspect", action="store_true")
    parser.add_argument("--device", help="BLE device address from --scan")
    parser.add_argument("--char", help="Notifying JSON characteristic UUID")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.scan:
        await scan()
    elif args.device and (args.inspect or args.char):
        await run_bridge(args)
    else:
        parser.error("Use --scan, or --device ADDRESS --inspect, or --device ADDRESS --char UUID")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Stopped.")

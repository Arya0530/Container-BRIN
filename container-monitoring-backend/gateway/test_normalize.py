"""Offline test with the known ESP32 receiver JSON shape."""
import json
from common import JsonStream, normalize_packet

sample = {
    "deviceID": 746996,
    "packetCounter": 7,
    "rssi": -51,
    "snr": 8.7,
    "door": False,
    "gps": {
        "lat": -7.7956, "lon": 110.3695, "alt": 0,
        "speed": 0, "sats": 7, "timeUTC": "2026/10/27,13:14:00",
    },
    "tujuan": "Solo", "perusahaan": "PT DUA", "isi": "TAS",
}
packet = normalize_packet(sample)
assert packet["deviceID"] == "746996"
assert packet["gps"]["lat"] == -7.7956
s = json.dumps(sample)
stream = JsonStream()
assert stream.feed(s[:18]) == []
assert stream.feed(s[18:]) == [sample]
assert normalize_packet({"device": "746996", "isi": "TAS"}) is None
print("PASS: ESP32 JSON normalized and BLE fragmentation handled")

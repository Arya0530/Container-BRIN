import 'package:flutter_test/flutter_test.dart';
import 'package:container_monitoring_flutter/brin/data.dart';

void main() {
  test('container model preserves metadata mapping', () {
    final c = UiContainer.fromJson({
      'container_id': 1,
      'series': 'TEST-001',
      'device_id': 'DEVICE-001',
      'company_name': 'PT Padi',
      'destination': 'Surabaya',
      'contents': 'Beras',
      'package': 'Karung',
      'status': 'Active',
    });
    expect(c.id, 1);
    expect(c.company, 'PT Padi');
    expect(c.destination, 'Surabaya');
    expect(c.contents, 'Beras');
    expect(c.package, 'Karung');
  });

  test('telemetry model preserves sensor field parsing', () {
    final t = UiTelemetry.fromJson({
      'packet_counter': 186,
      'recorded_at': '2026-10-29T09:41:19.096Z',
      'latitude': -7.734565,
      'longitude': 110.3779672,
      'door_status': 'CLOSED',
      'rssi': -89,
      'snr': 12.25,
    });
    expect(t.hasLocation, isTrue);
    expect(t.packetCounter, 186);
    expect(t.latitude, -7.734565);
    expect(t.longitude, 110.3779672);
    expect(t.door, 'CLOSED');
    expect(t.rssi, -89);
    expect(t.snr, 12.25);
  });

  test('older nested GPS payload stays compatible', () {
    final t = UiTelemetry.fromJson({
      'gps': {'latitude': -7.7, 'longitude': 110.3},
      'door': 'OPEN',
    });
    expect(t.hasLocation, isTrue);
    expect(t.latitude, -7.7);
    expect(t.longitude, 110.3);
    expect(t.door, 'OPEN');
  });
}

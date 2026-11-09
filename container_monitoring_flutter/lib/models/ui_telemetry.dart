import 'json_data.dart';

class UiTelemetry {
  const UiTelemetry({
    this.latitude,
    this.longitude,
    this.altitude,
    this.speed,
    this.door,
    this.rssi,
    this.snr,
    this.recordedAt,
    this.packetCounter,
  });

  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? speed;
  final String? door;
  final double? rssi;
  final double? snr;
  final DateTime? recordedAt;
  final int? packetCounter;

  factory UiTelemetry.fromJson(Map<String, dynamic> json) {
    final gps = jsonMap(jsonPick(json, ['gps', 'location']));
    final timeValue = jsonPick(json, [
      'recorded_at',
      'recordedAt',
      'timestamp',
      'time',
    ]);
    return UiTelemetry(
      latitude: jsonNumber(
        jsonPick(json, ['latitude', 'lat']) ??
            jsonPick(gps, ['latitude', 'lat']),
      ),
      longitude: jsonNumber(
        jsonPick(json, ['longitude', 'lon', 'lng']) ??
            jsonPick(gps, ['longitude', 'lon', 'lng']),
      ),
      altitude: jsonNumber(jsonPick(json, ['altitude', 'alt'])),
      speed: jsonNumber(jsonPick(json, ['speed', 'speed_kmh'])),
      door: jsonPick(json, ['door_status', 'doorStatus', 'door'])?.toString(),
      rssi: jsonNumber(jsonPick(json, ['rssi', 'RSSI'])),
      snr: jsonNumber(jsonPick(json, ['snr', 'SNR'])),
      recordedAt: jsonDate(timeValue),
      packetCounter: jsonInteger(
        jsonPick(json, ['packet_counter', 'packetCounter']),
      ),
    );
  }

  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;
}

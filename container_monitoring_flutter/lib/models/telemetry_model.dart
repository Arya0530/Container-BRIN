
class TelemetryModel {
  final int containerId;
  final int? packetCounter;
  final DateTime recordedAt;
  final double? latitude;
  final double? longitude;
  final String? doorStatus;
  final int? rssi;
  final double? snr;

  const TelemetryModel({
    required this.containerId,
    required this.packetCounter,
    required this.recordedAt,
    required this.latitude,
    required this.longitude,
    required this.doorStatus,
    required this.rssi,
    required this.snr,
  });

  // Convert the API response into a telemetry model.
  factory TelemetryModel.fromJson(Map<String, dynamic> json) {
    return TelemetryModel(
      containerId: json['container_id'] as int,
      packetCounter: json['packet_counter'] as int?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      doorStatus: json['door_status'] as String?,
      rssi: json['rssi'] as int?,
      snr: (json['snr'] as num?)?.toDouble(),
    );
  }
}

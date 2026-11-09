import '../models/ui_telemetry.dart';

// Determine connection status from the latest telemetry timestamp.
String telemetryConnectionStatus(UiTelemetry? telemetry) {
  final recordedAt = telemetry?.recordedAt;
  if (recordedAt == null) return 'No Data';

  final age = DateTime.now().toUtc().difference(recordedAt.toUtc());

  if (age.isNegative) return 'No Data';
  if (age <= const Duration(minutes: 5)) return 'Active';
  if (age <= const Duration(minutes: 10)) return 'Delayed';
  return 'Offline';
}

String displayTime(DateTime? time) {
  if (time == null) return '—';
  final t = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}-${two(t.month)}-${t.year} ${two(t.hour)}:${two(t.minute)}';
}

String displayNumber(double? value, {int places = 1, String suffix = ''}) {
  if (value == null) return '—';
  return '${value.toStringAsFixed(places)}$suffix';
}

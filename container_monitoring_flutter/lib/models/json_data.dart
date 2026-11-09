// Shared JSON parsing helpers for API models and services.
// Extracted from lib/brin/data.dart without changing parsing behavior.

Map<String, dynamic> jsonMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

dynamic jsonPick(Map<String, dynamic> json, List<String> names) {
  for (final name in names) {
    final value = json[name];
    if (value != null) return value;
  }
  return null;
}

String jsonString(dynamic v, [String fallback = '—']) {
  if (v == null) return fallback;
  final str = v.toString().trim();
  return str.isEmpty ? fallback : str;
}

double? jsonNumber(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '');
}

int? jsonInteger(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

DateTime? jsonDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

List<dynamic> jsonList(dynamic result, List<String> keys) {
  if (result is List) return result;
  if (result is Map) {
    for (final key in keys) {
      final value = result[key];
      if (value is List) return value;
    }
  }
  return <dynamic>[];
}

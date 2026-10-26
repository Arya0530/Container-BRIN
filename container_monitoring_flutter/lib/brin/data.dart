import 'dart:convert';

import 'package:http/http.dart' as http;

const String backendBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

dynamic _pick(Map<String, dynamic> json, List<String> names) {
  for (final name in names) {
    final value = json[name];
    if (value != null) return value;
  }
  return null;
}

String _string(dynamic v, [String fallback = '—']) {
  if (v == null) return fallback;
  final str = v.toString().trim();
  return str.isEmpty ? fallback : str;
}

double? _number(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '');
}

int? _integer(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

List<dynamic> _asList(dynamic result, List<String> keys) {
  if (result is List) return result;
  if (result is Map) {
    for (final key in keys) {
      final value = result[key];
      if (value is List) return value;
    }
  }
  return <dynamic>[];
}

class UiContainer {
  const UiContainer({
    required this.id,
    required this.series,
    required this.company,
    required this.destination,
    required this.contents,
    required this.package,
    required this.status,
  });

  final int id;
  final String series;
  final String company;
  final String destination;
  final String contents;
  final String package;
  final String status;

  factory UiContainer.fromJson(Map<String, dynamic> json) {
    final companyValue = _pick(json, [
      'company_name',
      'companyName',
      'company',
    ]);
    final companyName = companyValue is Map
        ? _string(
            _pick(_asMap(companyValue), [
              'company_name',
              'companyName',
              'name',
            ]),
          )
        : _string(companyValue);
    return UiContainer(
      id: _integer(_pick(json, ['container_id', 'containerId', 'id'])) ?? -1,
      series: _string(_pick(json, ['series', 'serial_number', 'serialNumber'])),
      company: companyName,
      destination: _string(_pick(json, ['destination', 'destination_name'])),
      contents: _string(_pick(json, ['contents', 'content', 'cargo'])),
      package: _string(_pick(json, ['package', 'packages', 'package_count'])),
      status: _string(_pick(json, ['status', 'container_status']), 'Unknown'),
    );
  }
}

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
    final gps = _asMap(_pick(json, ['gps', 'location']));
    final timeValue = _pick(json, [
      'recorded_at',
      'recordedAt',
      'timestamp',
      'time',
    ]);
    return UiTelemetry(
      latitude: _number(
        _pick(json, ['latitude', 'lat']) ?? _pick(gps, ['latitude', 'lat']),
      ),
      longitude: _number(
        _pick(json, ['longitude', 'lon', 'lng']) ??
            _pick(gps, ['longitude', 'lon', 'lng']),
      ),
      altitude: _number(_pick(json, ['altitude', 'alt'])),
      speed: _number(_pick(json, ['speed', 'speed_kmh'])),
      door: _pick(json, ['door_status', 'doorStatus', 'door'])?.toString(),
      rssi: _number(_pick(json, ['rssi', 'RSSI'])),
      snr: _number(_pick(json, ['snr', 'SNR'])),
      recordedAt: _date(timeValue),
      packetCounter: _integer(_pick(json, ['packet_counter', 'packetCounter'])),
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

class UiApi {
  UiApi._();
  static final UiApi instance = UiApi._();
  final http.Client _client = http.Client();
  final Map<int, Future<UiTelemetry?>> _latestCache = {};

  Future<dynamic> _get(String path) async {
    final uri = Uri.parse('$backendBaseUrl$path');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: $path');
    }
    return jsonDecode(response.body);
  }

  Future<List<UiContainer>> containers() async {
    final data = await _get('/api/containers');
    return _asList(data, ['containers', 'data', 'items'])
        .map((e) => UiContainer.fromJson(_asMap(e)))
        .where((c) => c.id >= 0)
        .toList();
  }

  Future<UiTelemetry?> latest(int id, {bool refresh = false}) {
    if (refresh) _latestCache.remove(id);
    return _latestCache.putIfAbsent(id, () async {
      try {
        final result = await _get('/api/containers/$id/latest');
        if (result == null) return null;
        final json = _asMap(result);
        final value = _pick(json, ['telemetry', 'data', 'latest']);
        return UiTelemetry.fromJson(value is Map ? _asMap(value) : json);
      } catch (_) {
        // A container may exist before its first telemetry packet arrives.
        return null;
      }
    });
  }

  Future<List<UiTelemetry>> history(
    int id, {
    DateTime? start,
    DateTime? end,
  }) async {
    if ((start == null) != (end == null)) {
      throw ArgumentError('Start and end must be provided together');
    }

    const pageSize = 500;
    var offset = 0;
    final all = <UiTelemetry>[];

    while (true) {
      final parameters = <String, String>{
        'limit': '$pageSize',
        'offset': '$offset',
      };

      if (start != null && end != null) {
        parameters['start'] = start.toUtc().toIso8601String();
        parameters['end'] = end.toUtc().toIso8601String();
      }

      final path = Uri(
        path: '/api/containers/$id/telemetry',
        queryParameters: parameters,
      ).toString();

      final response = await _get(path);

      final page = _asList(response, ['telemetry', 'data', 'items', 'records'])
          .map((e) {
            final json = Map<String, dynamic>.from(_asMap(e));
            final timestamp = json['recorded_at'];

            // Treat legacy timestamps without an offset as UTC.
            if (timestamp is String &&
                RegExp(
                  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?$',
                ).hasMatch(timestamp)) {
              json['recorded_at'] = '${timestamp}Z';
            }

            return UiTelemetry.fromJson(json);
          })
          .toList();

      all.addAll(page);

      if (page.length < pageSize) break;
      offset += page.length;
    }

    return all;
  }

  Future<void> createContainer({
    required String series,
    required String deviceId,
    required String company,
    required String destination,
    required String contents,
    required String packageName,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$backendBaseUrl/api/containers'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'series': series.trim(),
            'device_id': deviceId.trim(),
            'company_name': company.trim(),
            'destination': destination.trim(),
            'contents': contents.trim(),
            'package': packageName.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 201) {
      throw Exception(response.body.trim());
    }
  }

  Future<void> deleteContainer(int id) async {
    final response = await _client
        .delete(Uri.parse('$backendBaseUrl/api/containers/$id'))
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 204) {
      throw Exception(response.body.trim());
    }
    _latestCache.remove(id);
  }

  void clearLatestCache() => _latestCache.clear();
}

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

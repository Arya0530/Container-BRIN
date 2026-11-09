import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/json_data.dart';
import '../models/ui_container.dart';
import '../models/ui_telemetry.dart';

const String backendBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

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
    return jsonList(data, ['containers', 'data', 'items'])
        .map((e) => UiContainer.fromJson(jsonMap(e)))
        .where((c) => c.id >= 0)
        .toList();
  }

  Future<UiTelemetry?> latest(int id, {bool refresh = false}) {
    if (refresh) _latestCache.remove(id);
    return _latestCache.putIfAbsent(id, () async {
      try {
        final result = await _get('/api/containers/$id/latest');
        if (result == null) return null;
        final json = jsonMap(result);
        final value = jsonPick(json, ['telemetry', 'data', 'latest']);
        return UiTelemetry.fromJson(value is Map ? jsonMap(value) : json);
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

      final page = jsonList(response, ['telemetry', 'data', 'items', 'records'])
          .map((e) {
            final json = Map<String, dynamic>.from(jsonMap(e));
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

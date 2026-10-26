
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/container_model.dart';

import '../models/telemetry_model.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );


  // Fetch the latest telemetry for a specific container.
  Future<TelemetryModel> getLatestTelemetry(int containerId) async {
    final uri = Uri.parse(
      '$baseUrl/api/containers/$containerId/latest',
    );

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch telemetry: HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body)
        as Map<String, dynamic>;

    return TelemetryModel.fromJson(data);
  }


  // Fetch the container list from the Go backend.
  Future<List<ContainerModel>> getContainers() async {
    final uri = Uri.parse('$baseUrl/api/containers');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch containers: HTTP ${response.statusCode}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data.map((item) {
      return ContainerModel.fromJson(
        item as Map<String, dynamic>,
      );
    }).toList();
  }
}

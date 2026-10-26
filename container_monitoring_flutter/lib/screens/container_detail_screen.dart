
import 'package:flutter/material.dart';

import '../models/container_model.dart';
import '../models/telemetry_model.dart';
import '../services/api_service.dart';
import 'dart:async';

class ContainerDetailScreen extends StatefulWidget {
  final ContainerModel container;

  const ContainerDetailScreen({
    super.key,
    required this.container,
  });

  @override
  State<ContainerDetailScreen> createState() =>
      _ContainerDetailScreenState();
}

class _ContainerDetailScreenState extends State<ContainerDetailScreen> {
  final ApiService _apiService = ApiService();

  Timer? _refreshTimer;
  bool _isFetching = false;
  TelemetryModel? _telemetry;
  bool _isLoading = true;
  String? _error;


  @override
  void initState() {
    super.initState();

    _loadTelemetry();

    // Refresh telemetry every five seconds.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadTelemetry(silent: true),
    );
  }

  @override
  void dispose() {
    // Stop polling when the screen is removed.
    _refreshTimer?.cancel();
    super.dispose();
  }


  // Fetch telemetry and update the screen.

Future<void> _loadTelemetry({bool silent = false}) async {
  // Prevent overlapping API requests.
  if (_isFetching) return;

  _isFetching = true;

  if (!silent) {
    setState(() {
      _isLoading = true;
      _error = null;
    });
  }

  try {
    final result = await _apiService.getLatestTelemetry(
      widget.container.containerId,
    );

    if (!mounted) return;

    setState(() {
      _telemetry = result;
      _isLoading = false;
      _error = null;
    });
  } catch (error) {
    if (!mounted) return;

    // Keep displaying the last valid telemetry during
    // temporary network failures.
    if (!silent || _telemetry == null) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    } else {
      debugPrint('Telemetry refresh failed: $error');
    }
  } finally {
    _isFetching = false;
  }
}


  // Display a labeled telemetry value.
  Widget _infoTile(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 17),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Container ${widget.container.series}'),
        actions: [
          IconButton(
            onPressed: _loadTelemetry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadTelemetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final telemetry = _telemetry!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.container.companyName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),

        _infoTile(
          'Door Status',
          telemetry.doorStatus ?? 'Unknown',
        ),
        _infoTile(
          'Latitude',
          telemetry.latitude?.toString() ?? 'N/A',
        ),
        _infoTile(
          'Longitude',
          telemetry.longitude?.toString() ?? 'N/A',
        ),
        _infoTile(
          'RSSI',
          telemetry.rssi == null
              ? 'N/A'
              : '${telemetry.rssi} dBm',
        ),
        _infoTile(
          'SNR',
          telemetry.snr == null
              ? 'N/A'
              : '${telemetry.snr} dB',
        ),
        _infoTile(
          'Packet Counter',
          telemetry.packetCounter?.toString() ?? 'N/A',
        ),
        _infoTile(
          'Last Recorded (UTC)',
          telemetry.recordedAt.toUtc().toIso8601String(),
        ),
      ],
    );
  }
}

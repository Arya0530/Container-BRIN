import 'dart:async';
import 'package:flutter/material.dart';
import '../data.dart';
import '../widgets.dart';

class ContainerDetailPage extends StatefulWidget {
  const ContainerDetailPage({super.key, required this.container});
  final UiContainer container;
  @override
  State<ContainerDetailPage> createState() => _ContainerDetailPageState();
}

class _ContainerDetailPageState extends State<ContainerDetailPage> {
  UiTelemetry? _latest;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Future<void> _load() async {
    if (_busy) return;
    _busy = true;
    try {
      final value = await UiApi.instance.latest(
        widget.container.id,
        refresh: true,
      );
      if (mounted) setState(() => _latest = value ?? _latest);
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.container;
    final t = _latest;
    final status = telemetryConnectionStatus(t);
    final active = status == 'Active';
    return BrinPage(
      title: 'Container Detail',
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            BrinPanel(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: brinSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: brinRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Series: ${c.series}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Company: ${c.company}',
                          style: const TextStyle(
                            color: brinMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFE2FAED) : brinSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '● ${status}',
                      style: TextStyle(
                        fontSize: 11,
                        color: active
                            ? Colors.green
                            : status == 'Delayed'
                            ? Colors.orange
                            : brinRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            BrinMap(locations: t == null ? const [] : [t], height: 235),
            const SizedBox(height: 11),
            BrinPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Container Information',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: Metric(
                          icon: Icons.location_on,
                          label: 'Destination',
                          value: c.destination,
                        ),
                      ),
                      Expanded(
                        child: Metric(
                          icon: Icons.schedule,
                          label: 'Last Updated',
                          value: displayTime(t?.recordedAt),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Metric(
                          icon: Icons.inventory_2_outlined,
                          label: 'Contents',
                          value: c.contents,
                        ),
                      ),
                      Expanded(
                        child: Metric(
                          icon: Icons.navigation,
                          label: 'Latitude',
                          value: displayNumber(t?.latitude, places: 5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Metric(
                          icon: Icons.view_in_ar_outlined,
                          label: 'Package',
                          value: c.package,
                        ),
                      ),
                      Expanded(
                        child: Metric(
                          icon: Icons.navigation_outlined,
                          label: 'Longitude',
                          value: displayNumber(t?.longitude, places: 5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            BrinPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Realtime Monitoring',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _infoTile(
                          Icons.door_front_door_outlined,
                          'Door Status',
                          t?.door?.toUpperCase() ?? '—',
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _infoTile(
                          Icons.signal_cellular_alt,
                          'RSSI',
                          displayNumber(t?.rssi, places: 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: _infoTile(
                          Icons.sensors,
                          'SNR',
                          displayNumber(t?.snr),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _infoTile(
                          Icons.speed,
                          'Speed',
                          displayNumber(t?.speed, suffix: ' km/h'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            BrinPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location Status',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: t?.hasLocation == true
                            ? Colors.green
                            : brinMuted,
                        size: 13,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          t?.hasLocation == true
                              ? 'GPS available'
                              : 'Waiting for GPS',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Last location update: ${displayTime(t?.recordedAt)}',
                    style: const TextStyle(fontSize: 10, color: brinMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Row(
        children: [
          Icon(icon, color: brinRed, size: 26),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: brinMuted, fontSize: 10),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

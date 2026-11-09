import 'dart:async';
import 'package:flutter/material.dart';
import '../data.dart';
import '../widgets.dart';
import '../navigation.dart';
import 'container_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<List<UiContainer>> _containers;
  late Future<List<UiTelemetry>> _locations;
  late Future<Map<int, UiTelemetry?>> _latestById;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _reload();
    // Refresh the overview without requiring a manual page reload.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(_reload);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _reload() {
    UiApi.instance.clearLatestCache();
    _containers = UiApi.instance.containers();
    _latestById = _containers.then((items) async {
      final entries = await Future.wait(
        items.map((item) async {
          final latest = await UiApi.instance.latest(item.id);
          return MapEntry<int, UiTelemetry?>(item.id, latest);
        }),
      );
      return Map<int, UiTelemetry?>.fromEntries(entries);
    });

    _locations = _latestById.then(
      (values) => values.values
          .whereType<UiTelemetry>()
          .where((telemetry) => telemetry.hasLocation)
          .toList(),
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _containers;
    } catch (_) {
      // The FutureBuilder displays API failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrinPage(
      title: 'Container Monitoring Dashboard',
      drawer: brinDrawer(context, 'dashboard'),
      onSearch: () => navigateTo(context, 'list'),
      child: FutureBuilder<List<UiContainer>>(
        future: _containers,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: brinRed),
            );
          }
          if (snapshot.hasError) return loadError(snapshot.error, _refresh);

          final containers = snapshot.data ?? const <UiContainer>[];

          return RefreshIndicator(
            onRefresh: _refresh,
            color: brinRed,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
              children: [
                // Figma Frame 6: the map and the four counters share one border.
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: brinBorder, width: 1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    children: [
                      FutureBuilder<List<UiTelemetry>>(
                        future: _locations,
                        builder: (context, result) {
                          final locations =
                              (result.data ?? const <UiTelemetry>[])
                                  .where((item) => item.hasLocation)
                                  .toList();

                          if (locations.isEmpty) {
                            return const SizedBox(
                              height: 242,
                              child: Center(
                                child: Text(
                                  'No location data available',
                                  style: TextStyle(
                                    color: brinMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }

                          return BrinMap(
                            locations: locations,
                            height: 242,
                            framed: false,
                          );
                        },
                      ),
                      const Divider(height: 1, thickness: 1, color: brinBorder),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(7, 7, 7, 7),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFA8AC)),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 9,
                          ),
                          child: FutureBuilder<Map<int, UiTelemetry?>>(
                            future: _latestById,
                            builder: (context, latestSnapshot) {
                              if (latestSnapshot.hasError) {
                                return const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text('Device status unavailable'),
                                );
                              }

                              if (!latestSnapshot.hasData) {
                                return const SizedBox(
                                  height: 34,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: brinRed,
                                    ),
                                  ),
                                );
                              }

                              final latestById = latestSnapshot.data!;
                              var active = 0;
                              var offline = 0;
                              var delayed = 0;

                              for (final item in containers) {
                                final status = telemetryConnectionStatus(
                                  latestById[item.id],
                                );

                                switch (status) {
                                  case 'Active':
                                    active++;
                                  case 'Delayed':
                                    delayed++;
                                  case 'Offline':
                                    offline++;
                                }
                              }

                              return Row(
                                children: [
                                  _counter(
                                    'Total\nContainers',
                                    containers.length,
                                    Icons.inventory_2_outlined,
                                    brinRed,
                                  ),
                                  _counterDivider(),
                                  _counter(
                                    'Active',
                                    active,
                                    Icons.view_in_ar_outlined,
                                    const Color(0xFF00B96A),
                                  ),
                                  _counterDivider(),
                                  _counter(
                                    'Offline',
                                    offline,
                                    Icons.view_in_ar_outlined,
                                    brinRed,
                                  ),
                                  _counterDivider(),
                                  _counter(
                                    'Delayed',
                                    delayed,
                                    Icons.access_time,
                                    brinRed,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Containers',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => navigateTo(context, 'list'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'See all container →',
                        style: TextStyle(
                          color: brinRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (containers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No containers registered yet.')),
                  ),
                ...containers
                    .take(5)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _DashboardContainerCard(
                          container: item,
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ContainerDetailPage(container: item),
                            ),
                          ),
                          onDelete: () async {
                            if (await confirmDeleteContainer(context, item)) {
                              if (mounted) setState(_reload);
                            }
                          },
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _counterDivider() =>
      Container(height: 30, width: 1, color: const Color(0xFFE8E8E8));

  Widget _counter(String label, int count, IconData icon, Color color) {
    final green = color == const Color(0xFF00B96A);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 29,
              decoration: BoxDecoration(
                color: green ? const Color(0xFFE1FAEE) : brinSoft,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 8,
                      height: 1.1,
                      color: brinMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: brinDark,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dashboard-specific card; other screens keep their existing widgets.
class _DashboardContainerCard extends StatelessWidget {
  const _DashboardContainerCard({
    required this.container,
    required this.onOpen,
    required this.onDelete,
  });

  final UiContainer container;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UiTelemetry?>(
      future: UiApi.instance.latest(container.id),
      builder: (context, snapshot) {
        final telemetry = snapshot.data;
        final door = telemetry?.door?.toUpperCase() ?? '—';
        final open = door == 'OPEN';
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: brinBorder),
            borderRadius: BorderRadius.circular(9),
          ),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: brinSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: _DashboardContainerGlyph(size: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Series: ${container.series}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Company: ${container.company}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: brinMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Delete container',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete, color: brinRed, size: 22),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(height: 1, color: Color(0xFFE7E7E7)),
              ),
              Row(
                children: [
                  Expanded(
                    child: _cell(
                      Icons.location_on,
                      'Destination',
                      container.destination,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _cell(
                      Icons.view_in_ar_outlined,
                      'Contents',
                      container.contents,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _cell(
                      Icons.view_in_ar_outlined,
                      'Package',
                      container.package,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _cell(
                Icons.access_time,
                'Last Updated',
                displayTime(telemetry?.recordedAt),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Color(0xFFE7E7E7)),
              ),
              Row(
                children: [
                  Expanded(
                    child: _cell(
                      Icons.door_front_door_outlined,
                      'Door',
                      door,
                      valueColor: door == '—'
                          ? brinMuted
                          : open
                          ? const Color(0xFF00B957)
                          : brinRed,
                    ),
                  ),
                  Expanded(
                    child: _cell(
                      Icons.signal_cellular_alt,
                      'RSSI',
                      displayNumber(telemetry?.rssi, places: 0),
                    ),
                  ),
                  Expanded(
                    child: _cell(
                      Icons.sensors,
                      'SNR',
                      displayNumber(telemetry?.snr),
                    ),
                  ),
                  InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: brinSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'View detail →',
                        style: TextStyle(
                          fontSize: 10,
                          color: brinRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: const Color(0xFFE7E7E7),
  );

  Widget _cell(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: brinRed, size: 21),
        const SizedBox(width: 5),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: brinMuted, fontSize: 9),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? brinDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardContainerGlyph extends StatelessWidget {
  const _DashboardContainerGlyph({this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size),
    painter: _DashboardContainerPainter(),
  );
}

class _DashboardContainerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = brinRed
      ..strokeWidth = size.width * 0.09
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(
      size.width * .12,
      size.height * .26,
      size.width * .76,
      size.height * .52,
    );
    canvas.drawRect(rect, pen);
    for (var i = 1; i <= 3; i++) {
      final x = size.width * (.12 + i * .19);
      canvas.drawLine(
        Offset(x, size.height * .3),
        Offset(x, size.height * .74),
        pen,
      );
    }
    canvas.drawLine(
      Offset(size.width * .08, size.height * .18),
      Offset(size.width * .92, size.height * .18),
      pen,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'data.dart';
import 'widgets.dart';

Future<bool> _confirmDeleteContainer(
  BuildContext context,
  UiContainer container,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Container'),
      content: Text(
        'Delete container ${container.series}? '
        'Containers with telemetry history cannot be deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  try {
    await UiApi.instance.deleteContainer(container.id);
    if (!context.mounted) return false;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Container deleted')));
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    }
    return false;
  }
}

Widget _pageFor(String key) {
  switch (key) {
    case 'list':
      return const ContainerListPage();
    case 'add':
      return const AddContainerPage();
    case 'report':
      return const ParameterReportPage();
    case 'login':
      return const LoginPage();
    case 'settings':
      return const InfoPage(title: 'Settings');
    case 'help':
      return const InfoPage(title: 'Help');
    default:
      return const DashboardPage();
  }
}

void navigateTo(BuildContext context, String key, {bool replace = false}) {
  final route = MaterialPageRoute<void>(builder: (_) => _pageFor(key));
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

Widget _drawer(BuildContext context, String selected) => BrinDrawer(
  selected: selected,
  onNavigate: (key) {
    Navigator.pop(context);
    if (key != selected) navigateTo(context, key);
  },
);

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
      drawer: _drawer(context, 'dashboard'),
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
          if (snapshot.hasError) return _loadError(snapshot.error, _refresh);

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
                            if (await _confirmDeleteContainer(context, item)) {
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

class ContainerListPage extends StatefulWidget {
  const ContainerListPage({super.key});
  @override
  State<ContainerListPage> createState() => _ContainerListPageState();
}

class _ContainerListPageState extends State<ContainerListPage> {
  late Future<List<UiContainer>> _future;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final Set<int> _deletedIds = {};

  @override
  void initState() {
    super.initState();
    _future = UiApi.instance.containers();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    UiApi.instance.clearLatestCache();
    setState(() => _future = UiApi.instance.containers());
    try {
      await _future;
    } catch (_) {
      /* Handled by FutureBuilder. */
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrinPage(
      title: 'List Container',
      drawer: _drawer(context, 'list'),
      onSearch: () => _searchFocus.requestFocus(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search container series, company, destination...',
                hintStyle: const TextStyle(fontSize: 11, color: brinMuted),
                prefixIcon: const Icon(Icons.search, color: brinRed),
                filled: true,
                fillColor: brinSoft,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFFFD4D6)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<UiContainer>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData &&
                    snapshot.connectionState != ConnectionState.done)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return _loadError(snapshot.error, _refresh);
                final query = _search.text.trim().toLowerCase();
                final results = (snapshot.data ?? [])
                    .where((c) => !_deletedIds.contains(c.id))
                    .where(
                      (c) => '${c.series} ${c.company} ${c.destination}'
                          .toLowerCase()
                          .contains(query),
                    )
                    .toList();
                if (results.isEmpty)
                  return const Center(
                    child: Text('No matching containers found.'),
                  );
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 13),
                    itemBuilder: (context, index) => ContainerCard(
                      container: results[index],
                      onView: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ContainerDetailPage(container: results[index]),
                        ),
                      ),
                      onDelete: () async {
                        final container = results[index];
                        if (await _confirmDeleteContainer(context, container)) {
                          if (!mounted) return;
                          setState(() => _deletedIds.add(container.id));
                          await _refresh();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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

class AddContainerPage extends StatefulWidget {
  const AddContainerPage({super.key});
  @override
  State<AddContainerPage> createState() => _AddContainerPageState();
}

class _AddContainerPageState extends State<AddContainerPage> {
  final _formKey = GlobalKey<FormState>();
  final _series = TextEditingController();
  final _deviceId = TextEditingController();
  final _package = TextEditingController();
  bool _saving = false;
  final _destination = TextEditingController();
  final _contents = TextEditingController();
  final _company = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _series,
      _deviceId,
      _destination,
      _contents,
      _package,
      _company,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await UiApi.instance.createContainer(
        series: _series.text,
        deviceId: _deviceId.text,
        company: _company.text,
        destination: _destination.text,
        contents: _contents.text,
        packageName: _package.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Container added successfully')),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ContainerListPage()),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Add failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrinPage(
      title: 'Add Container',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field('Series', 'e.g. XX4028', _series),
                  _field('Device ID', 'e.g. STM32-002', _deviceId),
                  _field(
                    'Destination',
                    'e.g. Semarang - Makassar',
                    _destination,
                  ),
                  _field('Contents', 'e.g. Rice, Electronics, etc.', _contents),
                  _field('Package', 'e.g. Karung', _package),
                  _field('Company', 'e.g. PT Padi', _company),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.maybePop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: brinRed),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: brinRed,
                          ),
                          onPressed: _saving ? null : _save,
                          child: const Text('Add Container'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 11, color: brinMuted),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required field' : null,
          ),
        ],
      ),
    );
  }
}

class ParameterReportPage extends StatefulWidget {
  const ParameterReportPage({super.key});
  @override
  State<ParameterReportPage> createState() => _ParameterReportPageState();
}

class _ParameterReportPageState extends State<ParameterReportPage> {
  late Future<List<UiContainer>> _containersFuture;
  List<UiTelemetry> _records = [];
  UiContainer? _selected;
  String _period = 'Daily';
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;
  int _reportRequestId = 0;

  @override
  void initState() {
    super.initState();
    _containersFuture = UiApi.instance.containers();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final containers = await _containersFuture;
      if (!mounted || containers.isEmpty) return;
      setState(() => _selected = containers.first);
      await _getRecords(containers.first.id);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _getRecords(int id) async {
    final requestId = ++_reportRequestId;

    // The selected period determines the database query range.
    late final DateTime start;
    late final DateTime end;

    if (_period == 'Yearly') {
      start = DateTime(_date.year);
      end = DateTime(_date.year + 1);
    } else if (_period == 'Monthly') {
      start = DateTime(_date.year, _date.month);
      end = DateTime(_date.year, _date.month + 1);
    } else {
      start = DateTime(_date.year, _date.month, _date.day);
      end = DateTime(_date.year, _date.month, _date.day + 1);
    }

    setState(() {
      _loading = true;
      _error = null;
      _records = [];
    });

    try {
      final records = await UiApi.instance.history(id, start: start, end: end);

      if (!mounted || requestId != _reportRequestId || _selected?.id != id) {
        return;
      }

      setState(() => _records = records);
    } catch (error) {
      if (mounted && requestId == _reportRequestId) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && requestId == _reportRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  bool _inPeriod(DateTime? timestamp) {
    if (timestamp == null) return false;
    final value = timestamp.toLocal();

    if (value.year != _date.year) return false;
    if (_period == 'Yearly') return true;
    if (value.month != _date.month) return false;
    if (_period == 'Monthly') return true;
    return value.day == _date.day;
  }

  DateTime _bucketKey(DateTime timestamp) {
    final t = timestamp.toLocal();

    if (_period == 'Yearly') {
      return DateTime(t.year, t.month);
    }
    if (_period == 'Monthly') {
      return DateTime(t.year, t.month, t.day);
    }
    return DateTime(t.year, t.month, t.day, t.hour);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _monthName(int n) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[n - 1];
  }

  String _dateLabel() {
    if (_period == 'Yearly') return '${_date.year}';
    if (_period == 'Monthly') {
      return '${_monthName(_date.month)} ${_date.year}';
    }
    return '${_two(_date.day)}/${_two(_date.month)}/${_date.year}';
  }

  String _bucketLabel(DateTime key) {
    if (_period == 'Yearly') {
      return '${_monthName(key.month)} ${key.year}';
    }
    if (_period == 'Monthly') {
      return '${_two(key.day)} ${_monthName(key.month)} ${key.year}';
    }
    return '${_two(key.hour)}:00 - ${_two(key.hour)}:59';
  }

  Widget _metricText(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: brinSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, color: brinDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _records.where((r) => _inPeriod(r.recordedAt)).toList()
      ..sort(
        (a, b) => (b.recordedAt ?? DateTime(1970)).compareTo(
          a.recordedAt ?? DateTime(1970),
        ),
      );

    final groups = <DateTime, List<UiTelemetry>>{};
    for (final record in filtered) {
      final time = record.recordedAt;
      if (time == null) continue;
      groups.putIfAbsent(_bucketKey(time), () => []).add(record);
    }

    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return BrinPage(
      title: 'Parameter Report',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 22),
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: brinSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                for (final item in ['Daily', 'Monthly', 'Yearly'])
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _period = item);
                        final id = _selected?.id;
                        if (id != null) _getRecords(id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _period == item ? brinRed : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            color: _period == item ? Colors.white : brinRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              side: const BorderSide(color: brinBorder),
            ),
            icon: const Icon(
              Icons.calendar_today_outlined,
              color: brinRed,
              size: 17,
            ),
            label: Text(
              _dateLabel(),
              style: const TextStyle(fontSize: 12, color: brinDark),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(() => _date = picked);
                final id = _selected?.id;
                if (id != null) _getRecords(id);
              }
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<UiContainer>>(
            future: _containersFuture,
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) return const SizedBox.shrink();

              return DropdownButtonFormField<int>(
                initialValue: _selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Container',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                items: items.map((c) {
                  return DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(
                      '${c.series} - ${c.company}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _selected = items.firstWhere((c) => c.id == id);
                    _records = [];
                  });
                  _getRecords(id);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: brinRed)),
          if (!_loading && _error == null) ...[
            Text(
              '${filtered.length} readings in ${keys.length} '
              '${_period == 'Daily'
                  ? 'hours'
                  : _period == 'Monthly'
                  ? 'days'
                  : 'months'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: brinDark,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Showing available readings for the selected period.',
              style: TextStyle(fontSize: 10, color: brinMuted),
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Center(
                  child: Text('No telemetry for the selected period.'),
                ),
              ),
            for (final key in keys) ...[
              BrinPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: brinRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _bucketLabel(key),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '${groups[key]!.length} records',
                          style: const TextStyle(
                            fontSize: 10,
                            color: brinMuted,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      'Latest reading: '
                      '${displayTime(groups[key]!.first.recordedAt)}',
                      style: const TextStyle(fontSize: 11, color: brinMuted),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _metricText('Door', groups[key]!.first.door ?? '-'),
                        _metricText(
                          'Speed',
                          displayNumber(
                            groups[key]!.first.speed,
                            suffix: ' km/h',
                          ),
                        ),
                        _metricText(
                          'RSSI',
                          displayNumber(groups[key]!.first.rssi, places: 0),
                        ),
                        _metricText(
                          'SNR',
                          displayNumber(groups[key]!.first.snr),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrinPage(
      title: 'Login',
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Email/ Username',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _user,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: 'Enter your email or username',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Password',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline),
                      hintText: 'Enter your password',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required field' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => unavailable(context, 'Forgot password'),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: brinRed, fontSize: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: brinRed,
                      padding: const EdgeInsets.all(15),
                    ),
                    onPressed: () {
                      if (_form.currentState!.validate())
                        unavailable(context, 'Login');
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Secure access for container monitoring system.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: brinMuted),
          ),
        ],
      ),
    );
  }
}

class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => BrinPage(
    title: title,
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: BrinPanel(
        child: Text(
          title == 'Help'
              ? 'Container Monitoring support and documentation are not connected yet.'
              : 'Settings will be available when preference storage is implemented.',
        ),
      ),
    ),
  );
}

Widget _loadError(Object? error, Future<void> Function() retry) => Center(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: brinRed, size: 33),
        const SizedBox(height: 10),
        Text(
          'Could not load data: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  ),
);

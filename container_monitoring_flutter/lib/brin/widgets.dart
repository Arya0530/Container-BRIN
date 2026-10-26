import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';

const Color brinRed = Color(0xFFED171F);
const Color brinSoft = Color(0xFFFFE9EB);
const Color brinBackground = Color(0xFFFFFAF9);
const Color brinBorder = Color(0xFFFF7278);
const Color brinMuted = Color(0xFF7F899A);
const Color brinDark = Color(0xFF17202B);

ThemeData brinTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: brinBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brinRed,
      surface: brinBackground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: brinBackground,
      foregroundColor: brinDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class BrinLogo extends StatelessWidget {
  const BrinLogo({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/brin_logo.png',
      width: compact ? 115 : 180,
      height: compact ? 40 : 71,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Text(
        'BRIN',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: brinDark,
          fontSize: compact ? 23 : 27,
        ),
      ),
    );
  }
}

class BrinHeader extends StatelessWidget {
  const BrinHeader({super.key, this.onMenu, this.onBack, this.onSearch});
  final VoidCallback? onMenu;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
      child: SizedBox(
        height: 59,
        child: Row(
          children: [
            SizedBox(
              width: 35,
              child: IconButton(
                onPressed:
                    onMenu ?? onBack ?? () => Navigator.maybePop(context),
                padding: EdgeInsets.zero,
                icon: Icon(
                  onMenu != null ? Icons.menu : Icons.arrow_back_ios_new,
                  color: brinRed,
                  size: 24,
                ),
                tooltip: onMenu != null ? 'Open menu' : 'Back',
              ),
            ),
            const Expanded(child: Center(child: BrinLogo(compact: true))),
            if (onSearch != null)
              SizedBox(
                width: 108,
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: onSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brinRed,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    side: const BorderSide(color: Color(0xFFFFCBD0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.search, size: 17),
                  label: const Text(
                    'Search series',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: brinMuted),
                  ),
                ),
              )
            else
              const SizedBox(width: 35),
          ],
        ),
      ),
    );
  }
}

class BrinPage extends StatelessWidget {
  const BrinPage({
    super.key,
    required this.title,
    required this.child,
    this.drawer,
    this.onSearch,
    this.onBack,
  });
  final String title;
  final Widget child;
  final Widget? drawer;
  final VoidCallback? onSearch;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer,
      body: SafeArea(
        child: Builder(
          builder: (innerContext) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  BrinHeader(
                    onMenu: drawer == null
                        ? null
                        : () => Scaffold.of(innerContext).openDrawer(),
                    onBack:
                        onBack ??
                        () {
                          final navigator = Navigator.of(context);

                          if (navigator.canPop()) {
                            navigator.pop();
                          } else {
                            navigator.pushNamedAndRemoveUntil(
                              '/',
                              (route) => false,
                            );
                          }
                        },
                    onSearch: onSearch,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 10),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrinDrawer extends StatelessWidget {
  const BrinDrawer({
    super.key,
    required this.selected,
    required this.onNavigate,
  });
  final String selected;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = (screenWidth * 0.55).clamp(190.0, 230.0);
    final items = <(String, IconData, String)>[
      ('Dashboard', Icons.home_outlined, 'dashboard'),
      ('List Container', Icons.inventory_2_outlined, 'list'),
      ('Add Container', Icons.add_circle_outline, 'add'),
      ('Parameter Report', Icons.description_outlined, 'report'),
      ('Login', Icons.person_outline, 'login'),
      ('Settings', Icons.settings_outlined, 'settings'),
      ('Help', Icons.help_outline, 'help'),
    ];

    Widget navItem((String, IconData, String) item) {
      final active = selected == item.$3;
      return Material(
        color: active ? brinSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onNavigate(item.$3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
            child: Row(
              children: [
                Icon(item.$2, color: brinRed, size: 23),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? brinRed : brinDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Drawer(
      width: drawerWidth,
      backgroundColor: const Color(0xFFFFFAF9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const Center(child: BrinLogo()),
                    const SizedBox(height: 15),
                    const Text(
                      'Welcome!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: brinDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Monitor containers more easily',
                      style: TextStyle(fontSize: 11, color: brinMuted),
                    ),
                    const SizedBox(height: 17),
                    for (var i = 0; i < items.length; i++) ...[
                      if (i == 4)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Divider(color: brinRed, thickness: 0.7),
                        ),
                      navItem(items[i]),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              const Divider(color: brinRed, thickness: 0.7),
              const SizedBox(height: 12),
              const Text(
                'BRIN Container Monitoring',
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: brinDark,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'v1.0.0',
                style: TextStyle(fontSize: 10, color: brinMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrinPanel extends StatelessWidget {
  const BrinPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: brinBorder, width: 1),
      ),
      child: child,
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: brinRed, size: 21),
        const SizedBox(width: 5),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: brinMuted),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? brinDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ContainerCard extends StatelessWidget {
  const ContainerCard({
    super.key,
    required this.container,
    this.onView,
    this.onDelete,
  });

  final UiContainer container;
  final VoidCallback? onView;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UiTelemetry?>(
      future: UiApi.instance.latest(container.id),
      builder: (context, snapshot) {
        final telemetry = snapshot.data;
        final door = telemetry?.door ?? '-';
        final isOpen = door.toLowerCase() == 'open';

        return BrinPanel(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: brinSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: brinRed,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Series: ${container.series}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: brinDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Company: ${container.company}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: brinMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, color: brinRed, size: 21),
                      tooltip: 'Delete container',
                    ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      icon: Icons.location_on,
                      label: 'Destination',
                      value: container.destination,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Metric(
                      icon: Icons.view_in_ar_outlined,
                      label: 'Contents',
                      value: container.contents,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Metric(
                      icon: Icons.inventory_2_outlined,
                      label: 'Package',
                      value: container.package,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Metric(
                icon: Icons.access_time,
                label: 'Last Updated',
                value: displayTime(telemetry?.recordedAt),
              ),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      icon: Icons.door_front_door_outlined,
                      label: 'Door',
                      value: door.toUpperCase(),
                      valueColor: door == '-'
                          ? brinMuted
                          : isOpen
                          ? const Color(0xFF00B957)
                          : brinRed,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Metric(
                      icon: Icons.signal_cellular_alt,
                      label: 'RSSI',
                      value: displayNumber(telemetry?.rssi, places: 0),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Metric(
                      icon: Icons.sensors,
                      label: 'SNR',
                      value: displayNumber(telemetry?.snr),
                    ),
                  ),
                ],
              ),
              if (onView != null) ...[
                const SizedBox(height: 9),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: onView,
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: brinSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View detail',
                            style: TextStyle(
                              fontSize: 11,
                              color: brinRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: brinRed),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class BrinMap extends StatelessWidget {
  const BrinMap({
    super.key,
    required this.locations,
    this.height = 255,
    this.framed = true,
  });
  final List<UiTelemetry> locations;
  final double height;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final valid = locations.where((t) => t.hasLocation).toList();
    final center = valid.isNotEmpty
        ? LatLng(valid.first.latitude!, valid.first.longitude!)
        : const LatLng(-7.7956, 110.3695);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: framed ? Border.all(color: brinBorder) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey(
                '${center.latitude},${center.longitude},${valid.length}',
              ),
              options: MapOptions(
                initialCenter: center,
                initialZoom: valid.length == 1 ? 12.5 : 11,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'id.brin.container_monitoring',
                ),
                MarkerLayer(
                  markers: [
                    for (final location in valid)
                      Marker(
                        point: LatLng(location.latitude!, location.longitude!),
                        width: 42,
                        height: 42,
                        child: const Icon(
                          Icons.location_pin,
                          color: brinRed,
                          size: 40,
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            if (valid.isEmpty)
              Positioned(
                left: 8,
                right: 8,
                top: 12,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .93),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Text(
                        'No GPS coordinates available yet',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void unavailable(BuildContext context, String action) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '$action requires a backend endpoint that is not available yet.',
      ),
    ),
  );
}

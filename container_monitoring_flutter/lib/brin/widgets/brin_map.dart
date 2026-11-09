import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data.dart';
import 'theme.dart';

class BrinMap extends StatelessWidget {
  static final Map<bool, double> _savedZoom = {};
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
              key: ValueKey(valid.isEmpty),
              options: MapOptions(
                initialCenter: center,
                initialZoom:
                    _savedZoom[framed] ?? (valid.length == 1 ? 16.0 : 11),
                onPositionChanged: (camera, hasGesture) {
                  _savedZoom[framed] = camera.zoom;
                },
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

import 'package:flutter/material.dart';
import '../data.dart';
import 'panel.dart';
import 'theme.dart';

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

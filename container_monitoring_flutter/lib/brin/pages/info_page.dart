import 'package:flutter/material.dart';
import '../widgets.dart';

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

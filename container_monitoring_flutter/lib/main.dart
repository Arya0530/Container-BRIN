import 'package:flutter/material.dart';

import 'brin/screens.dart';
import 'brin/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ContainerMonitoringApp());
}

class ContainerMonitoringApp extends StatelessWidget {
  const ContainerMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BRIN Container Monitoring',
      debugShowCheckedModeBanner: false,
      theme: brinTheme(),
      home: const DashboardPage(),
    );
  }
}

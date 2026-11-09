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
      routes: {
        '/dashboard': (_) => const DashboardPage(),
        '/list': (_) => const ContainerListPage(),
        '/add': (_) => const AddContainerPage(),
        '/report': (_) => const ParameterReportPage(),
        '/login': (_) => const LoginPage(),
        '/settings': (_) => const InfoPage(title: 'Settings'),
        '/help': (_) => const InfoPage(title: 'Help'),
      },
      home: const DashboardPage(),
    );
  }
}

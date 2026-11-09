import 'package:flutter/material.dart';
import 'header.dart';
import 'theme.dart';

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

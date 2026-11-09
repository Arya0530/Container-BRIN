import 'package:flutter/material.dart';
import 'data.dart';
import 'widgets.dart';

// Shared navigation and UI helpers for the independent BRIN pages.
Future<bool> confirmDeleteContainer(
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

String _routeNameFor(String key) {
  switch (key) {
    case 'list':
      return '/list';
    case 'add':
      return '/add';
    case 'report':
      return '/report';
    case 'login':
      return '/login';
    case 'settings':
      return '/settings';
    case 'help':
      return '/help';
    default:
      return '/dashboard';
  }
}

void navigateTo(BuildContext context, String key, {bool replace = false}) {
  final routeName = _routeNameFor(key);
  if (replace) {
    Navigator.of(context).pushReplacementNamed(routeName);
  } else {
    Navigator.of(context).pushNamed(routeName);
  }
}

Widget brinDrawer(BuildContext context, String selected) => BrinDrawer(
  selected: selected,
  onNavigate: (key) {
    Navigator.pop(context);
    if (key != selected) navigateTo(context, key);
  },
);

Widget loadError(Object? error, Future<void> Function() retry) => Center(
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

import 'package:flutter/material.dart';

void unavailable(BuildContext context, String action) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '$action requires a backend endpoint that is not available yet.',
      ),
    ),
  );
}

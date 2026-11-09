import 'package:flutter/material.dart';

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

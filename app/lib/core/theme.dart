import 'package:flutter/material.dart';

ThemeData buildTheme() {
  const seed = Color(0xFF1D4ED8);
  final scheme = ColorScheme.fromSeed(seedColor: seed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFFAFAF9),
    appBarTheme: const AppBarTheme(centerTitle: false, backgroundColor: Colors.transparent, elevation: 0),
  );
}

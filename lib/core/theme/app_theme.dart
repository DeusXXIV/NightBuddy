import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      useMaterial3: true,
      brightness: Brightness.light,
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8F7F5),
      appBarTheme: const AppBarTheme(centerTitle: true),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepOrange,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F0F12),
      cardColor: const Color(0xFF1A1A20),
      appBarTheme: const AppBarTheme(centerTitle: true),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

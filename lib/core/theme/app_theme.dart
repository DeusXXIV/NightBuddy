import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light({bool highContrast = false}) {
    final scheme = highContrast
        ? ColorScheme.highContrastLight()
        : ColorScheme.fromSeed(seedColor: Colors.deepOrange);
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: Brightness.light,
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8F7F5),
      appBarTheme: const AppBarTheme(centerTitle: true),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 14),
      cardTheme: CardThemeData(
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData dark({bool highContrast = false}) {
    final scheme = highContrast
        ? ColorScheme.highContrastDark()
        : ColorScheme.fromSeed(
            seedColor: Colors.deepOrange,
            brightness: Brightness.dark,
          );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      scaffoldBackgroundColor:
          highContrast ? const Color(0xFF0A0A0C) : const Color(0xFF0F0F12),
      cardColor: highContrast ? const Color(0xFF141418) : const Color(0xFF1A1A20),
      appBarTheme: const AppBarTheme(centerTitle: true),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 14),
      cardTheme: CardThemeData(
        color: highContrast ? const Color(0xFF141418) : const Color(0xFF1A1A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Colors inspirats en la Ribera: verd d'arrossar i blau del Xúquer.
class Tema {
  Tema._();

  static const Color llavor = Color(0xFF2E7D5B);

  static ThemeData clar() => _base(ColorScheme.fromSeed(seedColor: llavor));

  static ThemeData fosc() => _base(ColorScheme.fromSeed(seedColor: llavor, brightness: Brightness.dark));

  static ThemeData _base(ColorScheme c) => ThemeData(
        colorScheme: c,
        useMaterial3: true,
        appBarTheme: AppBarTheme(backgroundColor: c.surface, centerTitle: false, scrolledUnderElevation: 2),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: c.outlineVariant),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      );
}

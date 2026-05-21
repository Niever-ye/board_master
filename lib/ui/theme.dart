import 'package:flutter/material.dart';

class AppTheme {
  static const Color woodLight = Color(0xFFDEB887);
  static const Color woodDark = Color(0xFFC4A265);
  static const Color woodBoard = Color(0xFFDCA470);
  static const Color gridLine = Color(0xFF4A3728);
  static const Color blackStone = Color(0xFF1A1A1A);
  static const Color whiteStone = Color(0xFFF5F5F0);
  static const Color accent = Color(0xFF6B4226);
  static const Color surface = Color(0xFFFDF5E6);
  static const Color textPrimary = Color(0xFF2C1810);

  static ThemeData get theme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF5C3A28),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      useMaterial3: true,
    );
  }
}

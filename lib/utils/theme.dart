import 'package:flutter/material.dart';

/// ============================================================
/// FortRun Theme — Pakistani Green Dark Mode
/// ============================================================
/// Primary:   Pakistani flag green (#006600 / a deeper variant)
/// Accent:    White / Moonstone highlights
/// Surface:   Rich dark grays
/// ============================================================

class FortRunTheme {
  // ── Brand Colors ───────────────────────────────────────────
  static const Color primaryGreen = Color(0xFF00A651);     // Vibrant Pakistan green
  static const Color primaryGreenDark = Color(0xFF007A3D);
  static const Color accentWhite = Color(0xFFF5F5F5);
  static const Color starGold = Color(0xFFFFD700);         // Star/gold accent

  // ── Surface & Background ──────────────────────────────────
  static const Color scaffoldDark = Color(0xFF0D0D0D);
  static const Color cardDark = Color(0xFF1A1A2E);
  static const Color cardDarkAlt = Color(0xFF16213E);
  static const Color surfaceDark = Color(0xFF0F3460);

  // ── Status Colors ─────────────────────────────────────────
  static const Color enemyRed = Color(0xFFE53935);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color safeBlue = Color(0xFF29B6F6);

  // ── Text ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF78909C);

  // ── Gradients ─────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00A651), Color(0xFF007A3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sabotageGradient = LinearGradient(
    colors: [Color(0xFFE53935), Color(0xFFFF6F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── ThemeData ─────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldDark,
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: starGold,
        surface: cardDark,
        error: enemyRed,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: primaryGreen),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 8,
        shadowColor: primaryGreen.withOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDarkAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: primaryGreen,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDarkAlt,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: textMuted.withOpacity(0.2),
    );
  }
}

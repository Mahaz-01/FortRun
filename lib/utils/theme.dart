import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================
/// FortRun Theme — Dark mode with Pakistani Green
/// Font: Outfit (modern, sporty, legible)
/// ============================================================

class FortRunTheme {
  // ── Brand Colors ───────────────────────────────────────────
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color primaryGreenDark = Color(0xFF00A651);
  static const Color primaryGreenDeep = Color(0xFF007A3D);
  static const Color accentWhite = Color(0xFFF5F5F5);
  static const Color starGold = Color(0xFFFFD700);
  static const Color starGoldDim = Color(0xFFB8860B);

  // ── Surface & Background ──────────────────────────────────
  static const Color scaffoldDark = Color(0xFF080808);
  static const Color cardDark = Color(0xFF111111);
  static const Color cardDarkAlt = Color(0xFF1A1A1A);
  static const Color cardDarkBorder = Color(0xFF252525);
  static const Color surfaceDark = Color(0xFF0F0F0F);

  // ── Status Colors ─────────────────────────────────────────
  static const Color enemyRed = Color(0xFFFF3D3D);
  static const Color enemyRedDim = Color(0xFFB71C1C);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color safeBlue = Color(0xFF29B6F6);
  static const Color clanPurple = Color(0xFF9C27B0);

  // ── Text ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF546E7A);

  // ── Gradients ─────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF007A3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF007A3D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF111111)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sabotageGradient = LinearGradient(
    colors: [Color(0xFFFF3D3D), Color(0xFFFF6F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF080808), Color(0xFF0D1A0D), Color(0xFF080808)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Glassmorphism helper ───────────────────────────────────
  static BoxDecoration glassCard({
    Color? borderColor,
    double opacity = 0.08,
    double radius = 16,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.08),
        width: 1,
      ),
    );
  }

  // ── ThemeData ─────────────────────────────────────────────
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.outfitTextTheme(
      ThemeData.dark().textTheme,
    );

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
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: primaryGreen),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardDarkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDarkAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardDarkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardDarkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        prefixIconColor: textMuted,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDarkAlt,
        contentTextStyle: GoogleFonts.outfit(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: cardDarkBorder),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dividerColor: cardDarkBorder,
      dividerTheme: const DividerThemeData(color: cardDarkBorder, thickness: 1),
    );
  }
}

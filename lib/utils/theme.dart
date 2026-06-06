import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================
/// FortRun Theme — Dark mode with Pakistani Green
/// Font: Outfit (modern, sporty, legible)
/// ============================================================

class FortRunTheme {
  // ── Brand Colors ───────────────────────────────────────────
  // ONE signature accent (green). Used only for identity, primary
  // actions, your route and your territory — never sprayed around.
  static const Color primaryGreen = Color(0xFF00D26A);
  static const Color primaryGreenDark = Color(0xFF00A957);
  static const Color primaryGreenDeep = Color(0xFF067F45);
  static const Color accentWhite = Color(0xFFF5F7FA);
  // Reserved semantic accents (rare): gold = points, red = enemy.
  static const Color starGold = Color(0xFFFFC53D);
  static const Color starGoldDim = Color(0xFFB8860B);

  // ── Surface & Background (warm-neutral greyscale ramp) ─────
  static const Color scaffoldDark = Color(0xFF0A0B0D);
  static const Color cardDark = Color(0xFF15171C);
  static const Color cardDarkAlt = Color(0xFF1C1F26);
  static const Color cardDarkBorder = Color(0xFF272B33);
  static const Color surfaceDark = Color(0xFF101216);

  // ── Status Colors ─────────────────────────────────────────
  static const Color enemyRed = Color(0xFFFF4D4D);
  static const Color enemyRedDim = Color(0xFFB71C1C);
  static const Color warningOrange = Color(0xFFFFA726);
  static const Color safeBlue = Color(0xFF4FB6E6);
  static const Color clanPurple = Color(0xFF9C27B0);

  // ── Text (three levels, that's it) ─────────────────────────
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF9BA3AD);
  static const Color textMuted = Color(0xFF5C646E);

  // ── Gradients ─────────────────────────────────────────────
  // Gradients are intentionally subtle (tight delta) — accent, not neon.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00D26A), Color(0xFF019B53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [Color(0xFF00D26A), Color(0xFF019B53)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1C1F26), Color(0xFF15171C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sabotageGradient = LinearGradient(
    colors: [Color(0xFFFF4D4D), Color(0xFFD63A2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFC53D), Color(0xFFE0941F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0B0D), Color(0xFF0C0E12), Color(0xFF0A0B0D)],
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
        elevation: 0,
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

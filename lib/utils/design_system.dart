import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

/// ============================================================
/// FortRun Design System — "Calm dark + one accent"
///
/// A single source of truth for spacing, radius, motion and a
/// fixed type scale. Use these tokens everywhere so every screen
/// feels like one cohesive product (Strava-grade restraint, no
/// neon spray). Colors live in [FortRunTheme]; this file governs
/// rhythm, shape and text.
/// ============================================================

class DS {
  DS._();

  // ── Spacing scale (4-based) ────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // ── Corner radius ──────────────────────────────────────────
  static const double rSm = 10;
  static const double rMd = 16;
  static const double rLg = 24;
  static const double rPill = 999;

  // ── Motion ─────────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // ── Type scale (one role per size) ─────────────────────────
  static TextStyle get display => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: FortRunTheme.textPrimary,
        height: 1.05,
        letterSpacing: -0.5,
      );

  static TextStyle get title => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: FortRunTheme.textPrimary,
        height: 1.15,
      );

  static TextStyle get body => GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: FortRunTheme.textSecondary,
        height: 1.35,
      );

  static TextStyle get label => GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: FortRunTheme.textSecondary,
      );

  static TextStyle get overline => GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: FortRunTheme.textMuted,
        letterSpacing: 1.5,
      );
}

/// ── AppCard ─────────────────────────────────────────────────
/// The single card surface used across the app. Flat, calm, one
/// hairline border — no glow, no gradient.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DS.lg),
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: DS.fast,
      padding: padding,
      decoration: BoxDecoration(
        color: FortRunTheme.cardDark,
        borderRadius: BorderRadius.circular(DS.rMd),
        border: Border.all(
          color: accent?.withOpacity(0.25) ?? FortRunTheme.cardDarkBorder,
          width: 1,
        ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

/// ── SectionHeader ───────────────────────────────────────────
/// Consistent overline + optional trailing action above lists.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DS.md),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: DS.overline),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// ── StatTile ────────────────────────────────────────────────
/// Big number + quiet label. The atom of every stats surface.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? FortRunTheme.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: c.withOpacity(0.9)),
          const SizedBox(height: DS.sm),
        ],
        Text(value, style: DS.display.copyWith(color: c, fontSize: 26)),
        const SizedBox(height: DS.xs),
        Text(label.toUpperCase(), style: DS.overline),
      ],
    );
  }
}

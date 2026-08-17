import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Brass & Fade" — the app's visual identity. Named colors and fonts live
/// here so every screen pulls from one source instead of hardcoding hex
/// values or font families inline.
class AppColors {
  const AppColors._();

  static const charcoal = Color(0xFF221D1A);
  static const chalk = Color(0xFFEDEAE3);
  static const brass = Color(0xFFA6803C);
  static const rust = Color(0xFF8C4A32);
  static const steel = Color(0xFF6B6862);

  /// Elevated surface (cards) on top of the chalk background — off-white
  /// rather than pure white, so cards stay part of the same warm-neutral
  /// family instead of reading as generic Material white.
  static const cardSurface = Color(0xFFFAF8F4);
  static const divider = Color(0xFFDCD5C6);

  /// Text colors when placed directly on brass/rust fills — dark enough
  /// for contrast without using flat black.
  static const onBrass = Color(0xFF2C1F0E);
  static const onRust = chalk;
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brass,
        onPrimary: AppColors.onBrass,
        secondary: AppColors.rust,
        onSecondary: AppColors.onRust,
        surface: AppColors.cardSurface,
        onSurface: AppColors.charcoal,
        surfaceContainerHighest: AppColors.chalk,
        error: AppColors.rust,
        onError: AppColors.onRust,
        outline: AppColors.divider,
      ),
      scaffoldBackgroundColor: AppColors.chalk,
    );

    final displayFont = GoogleFonts.bigShouldersDisplayTextTheme(base.textTheme);
    final bodyFont = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: bodyFont.copyWith(
        displayLarge: displayFont.displayLarge?.copyWith(fontWeight: FontWeight.w800),
        displayMedium: displayFont.displayMedium?.copyWith(fontWeight: FontWeight.w800),
        displaySmall: displayFont.displaySmall?.copyWith(fontWeight: FontWeight.w800),
        headlineLarge: displayFont.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
        headlineMedium: displayFont.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        headlineSmall: displayFont.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: displayFont.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.charcoal,
        foregroundColor: AppColors.chalk,
        elevation: 0,
        titleTextStyle: GoogleFonts.bigShouldersDisplay(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: AppColors.chalk,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.divider, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brass,
          foregroundColor: AppColors.onBrass,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brass, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardSurface,
        indicatorColor: AppColors.brass.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.brass : AppColors.steel,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.brass : AppColors.steel,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: AppColors.brass,
        backgroundColor: AppColors.chalk,
      ),
    );
  }
}

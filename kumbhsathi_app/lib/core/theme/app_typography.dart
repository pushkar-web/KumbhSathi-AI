import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Inter type scale — Design System v2 (DESIGN.md §3).
/// Display/headline weights are heavier with tighter tracking; metrics use
/// tabular figures via [numeric].
abstract final class AppTypography {
  static TextTheme textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
          fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.0),
      displayMedium: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.75),
      headlineLarge: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.25),
      headlineSmall:
          GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge:
          GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium:
          GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3),
      labelSmall: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
  }

  /// Apply to KPI numerals so digits align (DESIGN.md §3).
  static TextStyle numeric(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

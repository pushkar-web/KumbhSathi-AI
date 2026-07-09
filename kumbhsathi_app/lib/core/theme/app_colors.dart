import 'package:flutter/material.dart';

/// KumbhSathi AI — Design System v2 "Sanctum" color tokens.
/// See DESIGN.md §2. Premium government-grade palette: deep indigo-blue,
/// saffron accent, ivory-mist neutrals. Never neon.
///
/// v1 (Stitch) token names are kept below as aliases so no existing screen
/// breaks; new code should prefer the v2 names.
abstract final class AppColors {
  // ============================================================
  // v2 — Primary (deep indigo-blue)
  // ============================================================
  static const Color primary = Color(0xFF0B4FA3);
  static const Color primaryDeep = Color(0xFF08356F);
  static const Color primaryDim = Color(0xFF0A458F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFD6E5FA);
  static const Color onPrimaryContainer = Color(0xFF082B57);
  static const Color primaryBright = Color(0xFF5B96E8); // dark-mode primary

  // ============================================================
  // v2 — Accent (saffron; CTAs and live states only)
  // ============================================================
  static const Color accent = Color(0xFFF5820D);
  static const Color accentDeep = Color(0xFFD96C05);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accentContainer = Color(0xFFFDEBD7);
  static const Color onAccentContainer = Color(0xFF5C3100);

  // ============================================================
  // v2 — Semantic
  // ============================================================
  static const Color success = Color(0xFF1B8A5A);
  static const Color successContainer = Color(0xFFDCF3E8);
  static const Color onSuccessContainer = Color(0xFF0A4630);
  static const Color danger = Color(0xFFC93B3B);
  static const Color dangerContainer = Color(0xFFFBE3E3);
  static const Color onDangerContainer = Color(0xFF6E1414);
  static const Color warning = Color(0xFFB97D10);
  static const Color warningContainer = Color(0xFFFBF0D9);
  static const Color onWarningContainer = Color(0xFF5C3D00);
  static const Color info = Color(0xFF2C6FBF);
  static const Color infoContainer = Color(0xFFDDEAFB);
  static const Color hospital = Color(0xFF7D4CBB);
  static const Color hospitalContainer = Color(0xFFEDE3FA);

  // ============================================================
  // v2 — Neutrals / surfaces (light)
  // ============================================================
  static const Color background = Color(0xFFF2F5FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFFBFCFE);
  static const Color surfaceSunken = Color(0xFFEAEFF6);
  static const Color ink = Color(0xFF101826);
  static const Color inkMedium = Color(0xFF4A5568);
  static const Color inkFaint = Color(0xFF8B96A5);
  static const Color hairline = Color(0xFFE3E9F2);
  static const Color outline = Color(0xFFB9C2CF);

  // ============================================================
  // v2 — Neutrals / surfaces (dark)
  // ============================================================
  static const Color backgroundDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF121B2C);
  static const Color surfaceRaisedDark = Color(0xFF182337);
  static const Color surfaceSunkenDark = Color(0xFF0E1626);
  static const Color inkDark = Color(0xFFE8EDF5);
  static const Color inkMediumDark = Color(0xFFA7B2C3);
  static const Color inkFaintDark = Color(0xFF6C7A8F);
  static const Color hairlineDark = Color(0xFF223049);

  // ============================================================
  // v2 — Gradients (hero/nav/CTA surfaces ONLY)
  // ============================================================
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDeep],
  );
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFFE06D00)],
  );
  static const LinearGradient scrimGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0x8C08356F)],
  );

  // ============================================================
  // Status helpers
  // ============================================================
  static const Color statusInfo = info;
  static const Color statusFound = success;
  static const Color statusSearching = accent;
  static const Color statusCritical = danger;
  static const Color statusHospital = hospital;

  static const Color priorityLow = success;
  static const Color priorityMedium = warning;
  static const Color priorityHigh = accent;
  static const Color priorityCritical = danger;

  // ============================================================
  // v1 (Stitch) aliases — kept for compatibility; prefer v2 names.
  // ============================================================
  static const Color secondary = Color(0xFF2C5BB6);
  static const Color secondaryDim = Color(0xFF1B4FA9);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = primaryContainer;
  static const Color onSecondaryContainer = onPrimaryContainer;
  static const Color secondaryFixed = primaryContainer;
  static const Color secondaryFixedDim = Color(0xFFC5D4FF);
  static const Color onSecondaryFixed = Color(0xFF003B8D);
  static const Color onSecondaryFixedVariant = Color(0xFF2858B2);

  static const Color tertiary = accentDeep;
  static const Color tertiaryDim = Color(0xFFB55A04);
  static const Color onTertiary = onAccent;
  static const Color tertiaryContainer = accent;
  static const Color onTertiaryContainer = Color(0xFF371200);
  static const Color tertiaryFixed = accent;
  static const Color tertiaryFixedDim = accentDeep;
  static const Color onTertiaryFixed = Color(0xFF000000);
  static const Color onTertiaryFixedVariant = Color(0xFF471900);

  static const Color error = danger;
  static const Color errorDim = Color(0xFF8F1F1F);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFF3A6A6);
  static const Color onErrorContainer = Color(0xFF5C0E0E);

  static const Color onBackground = ink;
  static const Color onSurface = ink;
  static const Color onSurfaceVariant = inkMedium;
  static const Color surfaceVariant = surfaceSunken;
  static const Color surfaceBright = background;
  static const Color surfaceDim = Color(0xFFD8DFE9);
  static const Color surfaceContainerLowest = surface;
  static const Color surfaceContainerLow = surfaceRaised;
  static const Color surfaceContainer = Color(0xFFEDF1F7);
  static const Color surfaceContainerHigh = surfaceSunken;
  static const Color surfaceContainerHighest = Color(0xFFE0E7F0);
  static const Color outlineVariant = hairline;
  static const Color inverseSurface = Color(0xFF0B0F11);
  static const Color inverseOnSurface = Color(0xFF9A9DA0);
  static const Color inversePrimary = primaryBright;
  static const Color surfaceTint = primary;

  static const Color primaryFixed = primaryBright;
  static const Color primaryFixedDim = Color(0xFF4F86D6);
  static const Color onPrimaryFixed = Color(0xFF000000);
  static const Color onPrimaryFixedVariant = Color(0xFF002957);
}

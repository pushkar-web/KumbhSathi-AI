import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Soft diffuse shadow presets (DESIGN.md §4). Shadow ink is the deep
/// primary, never pure black, which keeps depth "premium" not "harsh".
abstract final class AppShadows {
  static const Color _inkShadow = Color(0xFF0F2A5A);

  /// Default card elevation.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: _inkShadow.withValues(alpha: 0.05),
          offset: const Offset(0, 2),
          blurRadius: 10,
        ),
        BoxShadow(
          color: _inkShadow.withValues(alpha: 0.06),
          offset: const Offset(0, 8),
          blurRadius: 24,
        ),
      ];

  /// Sticky bars, floating panels, dialogs.
  static List<BoxShadow> get raised => [
        BoxShadow(
          color: _inkShadow.withValues(alpha: 0.08),
          offset: const Offset(0, 4),
          blurRadius: 16,
        ),
        BoxShadow(
          color: _inkShadow.withValues(alpha: 0.10),
          offset: const Offset(0, 12),
          blurRadius: 32,
        ),
      ];

  /// Accent CTA buttons only.
  static List<BoxShadow> get cta => [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.28),
          offset: const Offset(0, 6),
          blurRadius: 18,
        ),
      ];
}

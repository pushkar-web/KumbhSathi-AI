import 'package:flutter/animation.dart';

/// Spacing, radius, breakpoint and motion tokens (DESIGN.md §4).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page padding.
  static const double gutterMobile = 16;
  static const double gutterDesktop = 32;

  /// Desktop content max width.
  static const double contentMaxWidth = 1280;
}

abstract final class AppRadius {
  static const double chip = 8;
  static const double input = 12;
  static const double button = 12;
  static const double card = 16;
  static const double sheet = 20;
  static const double modal = 24;
  static const double hero = 28;
  static const double pill = 999;
}

abstract final class AppBreakpoints {
  static const double mobile = 600;
  static const double desktop = 1100;
}

abstract final class AppMotion {
  static const Duration enter = Duration(milliseconds: 240);
  static const Duration exit = Duration(milliseconds: 180);
  static const Duration counter = Duration(milliseconds: 700);
  static const Duration staggerStep = Duration(milliseconds: 50);
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeIn;
}

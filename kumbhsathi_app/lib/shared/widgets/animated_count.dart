import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Animated numeral with tabular figures (DESIGN.md §5).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(
    this.value, {
    super.key,
    this.style,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
  });

  final num value;
  final TextStyle? style;
  final int decimals;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.headlineLarge!;
    return TweenAnimationBuilder<double>(
      duration: AppMotion.counter,
      curve: AppMotion.easeOut,
      tween: Tween(begin: 0, end: value.toDouble()),
      builder: (context, v, _) => Text(
        '$prefix${v.toStringAsFixed(decimals)}$suffix',
        style: AppTypography.numeric(base),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_spacing.dart';

/// Shimmer building blocks — skeletons must mirror final layout
/// (DESIGN.md §8-1). Never show a bare spinner for content areas.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = AppRadius.chip,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHigh,
      highlightColor: scheme.surfaceContainerLow,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton list of card-shaped rows.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.items = 4, this.itemHeight = 88});

  final int items;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ShimmerBox(height: itemHeight, radius: AppRadius.card),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

/// Premium card (DESIGN.md §5): theme surface + hairline border + soft
/// diffuse shadow, radius 16, optional 3px accent bar and tap ripple.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.base),
    this.accentColor,
    this.onTap,
    this.raised = false,
    this.color,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Renders a 3px rounded bar on the left edge (status/priority accents).
  final Color? accentColor;
  final VoidCallback? onTap;

  /// Uses the stronger [AppShadows.raised] elevation.
  final bool raised;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(AppRadius.card));

    Widget content = Padding(padding: padding, child: child);

    if (accentColor != null) {
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: radius,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: raised ? AppShadows.raised : AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

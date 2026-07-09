import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

/// Primary call-to-action on the accent gradient (DESIGN.md §5).
/// Use sparingly — one per view. `PrimaryCta.tonal` is the quieter sibling.
class PrimaryCta extends StatelessWidget {
  const PrimaryCta({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
  })  : _tonal = false;

  /// Tonal (primaryContainer) variant for secondary actions.
  const PrimaryCta.tonal({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
  })  : _tonal = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final bool _tonal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;
    const radius = BorderRadius.all(Radius.circular(AppRadius.button));

    final fg = _tonal ? scheme.onPrimaryContainer : Colors.white;

    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        else ...[
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
          if (icon != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(icon, size: 20, color: fg),
          ],
        ],
      ],
    );

    return AnimatedOpacity(
      duration: AppMotion.exit,
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: _tonal ? null : AppColors.accentGradient,
          color: _tonal ? scheme.primaryContainer : null,
          borderRadius: radius,
          boxShadow: enabled && !_tonal ? AppShadows.cta : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/ai_providers.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/ai/ai_router.dart';

/// Animated connectivity strip (DESIGN.md §5). Slides in when offline;
/// reassures that on-device AI keeps working.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    final gemmaReady = ref.watch(
        gemmaServiceProvider.select((s) => s.isReady));

    return AnimatedSwitcher(
      duration: AppMotion.enter,
      switchInCurve: AppMotion.easeOut,
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        axisAlignment: -1,
        child: child,
      ),
      child: online
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('offline'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: 10),
              color: AppColors.warningContainer,
              child: Row(
                children: [
                  const Icon(Symbols.cloud_off,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      gemmaReady
                          ? 'Offline — on-device AI active, changes will sync'
                          : 'Offline — changes will sync when connected',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.onWarningContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Compact pill showing the live AI routing mode (DESIGN.md §7.3).
class AiModeChip extends ConsumerWidget {
  const AiModeChip({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(aiModeProvider);
    final (icon, label, fg, bg) = switch (mode) {
      AiMode.groqCloud => (
          Symbols.bolt,
          'Groq Cloud',
          AppColors.primary,
          AppColors.primaryContainer
        ),
      AiMode.gemmaOnDevice => (
          Symbols.smartphone,
          'Gemma on-device',
          AppColors.success,
          AppColors.successContainer
        ),
      AiMode.unavailable => (
          Symbols.block,
          'AI unavailable',
          AppColors.inkMedium,
          AppColors.surfaceSunken
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 13 : 15, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

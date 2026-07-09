import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import 'ai_interview_screen.dart';
import 'register_missing_person_screen.dart';

/// Case status tracker — Design System v2 "Sanctum" (DESIGN.md §6.1).
/// Case header card, animated vertical timeline (done / pulsing active /
/// pending), officer contact card and a sticky help CTA. Offline-first:
/// update requests are queued through Hive when the network is away.
class ComplaintTrackerScreen extends ConsumerStatefulWidget {
  const ComplaintTrackerScreen({super.key});

  @override
  ConsumerState<ComplaintTrackerScreen> createState() =>
      _ComplaintTrackerScreenState();
}

class _ComplaintTrackerScreenState
    extends ConsumerState<ComplaintTrackerScreen> {
  int _caseIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cases = ref.watch(casesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: cases.when(
                loading: () => const _TrackerLoading(),
                error: (_, __) => EmptyState(
                  icon: Symbols.cloud_off,
                  title: 'Could not load your case',
                  subtitle: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(casesProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Symbols.person_search,
                      title: 'No cases to track',
                      subtitle:
                          'Report a missing person and follow every step of '
                          'the search here.',
                      actionLabel: 'Report Missing Person',
                      onAction: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const RegisterMissingPersonScreen(),
                          ),
                        );
                      },
                    );
                  }
                  final index = _caseIndex.clamp(0, items.length - 1);
                  return _buildTracker(items, index);
                },
              ),
            ),
            const _TrackerHelpBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTracker(List<Map<String, dynamic>> items, int index) {
    final data = items[index];
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutterMobile,
        AppSpacing.lg,
        AppSpacing.gutterMobile,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Track Case',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live status of your report',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(casesProvider),
                icon: Icon(Symbols.refresh,
                    size: 22, color: scheme.primary),
              ),
            ],
          ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06),
          if (items.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _TrackerCaseChip(
                      label: (items[i]['missing_person_name']
                              as String?) ??
                          'Case ${i + 1}',
                      selected: i == index,
                      onTap: () => setState(() => _caseIndex = i),
                    ),
                    if (i < items.length - 1)
                      const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            )
                .animate(delay: 40.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),
          ],
          const SizedBox(height: AppSpacing.base),
          _TrackerCaseHeaderCard(data: data)
              .animate(delay: 80.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06, curve: Curves.easeOutCubic),
          const SectionHeader('Case Progress', icon: Symbols.timeline)
              .animate(delay: 120.ms)
              .fadeIn(duration: 240.ms),
          _TrackerTimelineCard(data: data)
              .animate(delay: 160.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06, curve: Curves.easeOutCubic),
          const SectionHeader('Investigating Officer',
                  icon: Symbols.local_police)
              .animate(delay: 200.ms)
              .fadeIn(duration: 240.ms),
          _TrackerOfficerCard(
            caseId: (data['case_id'] as String?) ?? '—',
          )
              .animate(delay: 240.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

// ============================================================
// Helpers
// ============================================================
String _trackerElapsed(String? iso) {
  final t = DateTime.tryParse(iso ?? '');
  if (t == null) return '—';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m ago';
  return '${d.inDays}d ago';
}

Color _trackerStatusColor(String status) => switch (status) {
      'Pending' => AppColors.warning,
      'Searching' => AppColors.accent,
      'Reunited' => AppColors.success,
      'Transferred to hospital' => AppColors.hospital,
      'Unresolved' => AppColors.danger,
      _ => AppColors.info,
    };

/// Index of the step currently in progress; 5 means every step is done.
int _trackerActiveIndex(String status) => switch (status) {
      'Pending' => 2,
      'Searching' => 3,
      'Transferred to hospital' => 3,
      'Unresolved' => 3,
      'Reunited' => 5,
      _ => 2,
    };

String _trackerStepTime(DateTime base, Duration offset) =>
    DateFormat('d MMM, h:mm a').format(base.add(offset));

// ============================================================
// Loading skeleton — mirrors the final layout
// ============================================================
class _TrackerLoading extends StatelessWidget {
  const _TrackerLoading();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutterMobile,
        AppSpacing.lg,
        AppSpacing.gutterMobile,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 160, height: 26, radius: AppRadius.chip),
          SizedBox(height: AppSpacing.sm),
          ShimmerBox(width: 220, height: 14, radius: AppRadius.chip),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(height: 148, radius: AppRadius.card),
          SizedBox(height: AppSpacing.xl),
          ShimmerBox(height: 320, radius: AppRadius.card),
          SizedBox(height: AppSpacing.xl),
          ShimmerBox(height: 88, radius: AppRadius.card),
        ],
      ),
    );
  }
}

// ============================================================
// Case selector chip
// ============================================================
class _TrackerCaseChip extends StatelessWidget {
  const _TrackerCaseChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.exit,
          curve: Curves.easeOut,
          height: 40,
          alignment: Alignment.center,
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color:
                selected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Case header card
// ============================================================
class _TrackerCaseHeaderCard extends StatelessWidget {
  const _TrackerCaseHeaderCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;

    final name = (data['missing_person_name'] as String?) ?? 'Unknown';
    final caseId = (data['case_id'] as String?) ?? '—';
    final status = (data['status'] as String?) ?? 'Pending';
    final priority = (data['priority'] as String?) ?? 'Medium';
    final lastSeen = (data['last_seen_location'] as String?) ?? '—';
    final elapsed = _trackerElapsed(data['reported_at'] as String?);

    return AppCard(
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(
                name,
                size: 56,
                statusDot: _trackerStatusColor(status),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Symbols.tag,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            caseId,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatusBadge.fromLabel(status),
              const SizedBox(width: AppSpacing.sm),
              PriorityBadge.fromLabel(priority),
              const Spacer(),
              Icon(Symbols.schedule,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text(
                elapsed,
                style: text.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Row(
              children: [
                Icon(Symbols.pin_drop, size: 16, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Last seen: $lastSeen',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Timeline
// ============================================================
enum _TrackerStepState { done, active, pending }

class _TrackerTimelineCard extends ConsumerWidget {
  const _TrackerTimelineCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = (data['status'] as String?) ?? 'Pending';
    final priority = (data['priority'] as String?) ?? 'Medium';
    final lastSeen = (data['last_seen_location'] as String?) ?? '—';
    final caseId = (data['case_id'] as String?) ?? '—';
    final reported =
        DateTime.tryParse((data['reported_at'] as String?) ?? '')
                ?.toLocal() ??
            DateTime.now();
    final active = _trackerActiveIndex(status);

    _TrackerStepState stateFor(int i) {
      if (i < active) return _TrackerStepState.done;
      if (i == active && active < 5) return _TrackerStepState.active;
      return _TrackerStepState.pending;
    }

    final steps = <_TrackerStep>[
      _TrackerStep(
        state: stateFor(0),
        title: 'Case Registered',
        subtitle: _trackerStepTime(reported, Duration.zero),
      ),
      _TrackerStep(
        state: stateFor(1),
        title: 'AI Triage Completed',
        subtitle: stateFor(1) == _TrackerStepState.done
            ? _trackerStepTime(reported, const Duration(minutes: 14))
            : 'Pending',
        extra: stateFor(1) == _TrackerStepState.done
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PriorityBadge.fromLabel(priority),
                ],
              )
            : null,
      ),
      _TrackerStep(
        state: stateFor(2),
        title: 'Volunteer Assigned',
        subtitle: switch (stateFor(2)) {
          _TrackerStepState.done =>
            _trackerStepTime(reported, const Duration(hours: 1, minutes: 20)),
          _TrackerStepState.active => 'Assignment in progress',
          _TrackerStepState.pending => 'Pending',
        },
        extra: stateFor(2) == _TrackerStepState.done
            ? const _TrackerStepChip(
                icon: Symbols.person_pin,
                label: 'Assigned to Amit Singh (VOL-0342)',
              )
            : null,
      ),
      _TrackerStep(
        state: stateFor(3),
        title: 'Search in Progress',
        subtitle: switch (stateFor(3)) {
          _TrackerStepState.done =>
            _trackerStepTime(reported, const Duration(hours: 2)),
          _TrackerStepState.active => 'Live now',
          _TrackerStepState.pending => 'Pending',
        },
        extra: stateFor(3) != _TrackerStepState.pending
            ? _TrackerStepChip(
                icon: Symbols.travel_explore,
                label: 'Focus zone: $lastSeen',
              )
            : null,
      ),
      _TrackerStep(
        state: stateFor(4),
        title: 'Reunited',
        subtitle: stateFor(4) == _TrackerStepState.done
            ? 'Case closed — reunited safely'
            : 'Awaiting reunion confirmation',
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            _TrackerTimelineRow(
              step: steps[i],
              isLast: i == steps.length - 1,
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _requestUpdate(context, ref, caseId),
              icon: const Icon(Symbols.sync, size: 18),
              label: const Text('Request status update'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestUpdate(
      BuildContext context, WidgetRef ref, String caseId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(hiveServiceProvider).queueRequest(
        path: '/cases/$caseId/request-update',
        method: 'POST',
        body: {
          'case_id': caseId,
          'requested_at': DateTime.now().toIso8601String(),
        },
      );
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content:
              Text('Update requested — it will sync when you are online.'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not queue the request. Please try again.'),
        ),
      );
    }
  }
}

class _TrackerStep {
  const _TrackerStep({
    required this.state,
    required this.title,
    required this.subtitle,
    this.extra,
  });

  final _TrackerStepState state;
  final String title;
  final String subtitle;
  final Widget? extra;
}

class _TrackerStepChip extends StatelessWidget {
  const _TrackerStepChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerTimelineRow extends StatelessWidget {
  const _TrackerTimelineRow({required this.step, required this.isLast});

  final _TrackerStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;

    final titleColor = switch (step.state) {
      _TrackerStepState.done => scheme.onSurface,
      _TrackerStepState.active => AppColors.accentDeep,
      _TrackerStepState.pending => scheme.onSurfaceVariant,
    };
    final railColor = step.state == _TrackerStepState.done
        ? AppColors.success.withValues(alpha: 0.45)
        : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                _TrackerDot(state: step.state),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.4,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: railColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: text.titleMedium?.copyWith(
                      fontSize: 15,
                      color: titleColor,
                      fontWeight: step.state == _TrackerStepState.active
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: text.labelSmall?.copyWith(
                      color: step.state == _TrackerStepState.pending
                          ? scheme.outline
                          : scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (step.extra != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    step.extra!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerDot extends StatelessWidget {
  const _TrackerDot({required this.state});

  final _TrackerStepState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (state) {
      case _TrackerStepState.done:
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Symbols.check,
              size: 15, weight: 700, color: Colors.white),
        );
      case _TrackerStepState.active:
        return SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.30),
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(
                    begin: const Offset(0.55, 0.55),
                    end: const Offset(1.25, 1.25),
                    duration: 1100.ms,
                    curve: Curves.easeOut,
                  )
                  .fadeOut(duration: 1100.ms),
              Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      case _TrackerStepState.pending:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant, width: 2),
          ),
        );
    }
  }
}

// ============================================================
// Officer contact card
// ============================================================
class _TrackerOfficerCard extends StatelessWidget {
  const _TrackerOfficerCard({required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;

    return AppCard(
      child: Row(
        children: [
          const PersonAvatar('Arjun Verma',
              size: 48, statusDot: AppColors.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insp. Arjun Verma',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Investigating Officer • Sector 4 Chowki',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _TrackerContactAction(
            icon: Symbols.call,
            tooltip: 'Call officer',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                      'Connecting you to the officer for case $caseId…'),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          _TrackerContactAction(
            icon: Symbols.chat,
            tooltip: 'Message officer',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                      'Messaging opens once the officer accepts your case.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrackerContactAction extends StatelessWidget {
  const _TrackerContactAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: scheme.primaryContainer,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Sticky help CTA
// ============================================================
class _TrackerHelpBar extends StatelessWidget {
  const _TrackerHelpBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutterMobile, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: AppShadows.raised,
      ),
      child: Material(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiInterviewScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.md),
            child: Row(
              children: [
                const Icon(Symbols.support_agent,
                    size: 22, color: AppColors.accentDeep),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need help right now?',
                        style: text.labelLarge?.copyWith(
                          color: AppColors.onAccentContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Talk to the AI assistant or dial helpline 1947',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: AppColors.onAccentContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Symbols.chevron_right,
                    size: 22, color: AppColors.accentDeep),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

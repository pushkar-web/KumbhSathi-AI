import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import 'found_person_face_scan.dart';
import 'navigation_map_screen.dart';

/// Assigned Case detail — DESIGN.md §6.3. Person hero card, identification
/// checklist, map preview and a sticky action bar
/// (Navigate / Found — face scan / Report issue).
class AssignedCaseScreen extends ConsumerStatefulWidget {
  const AssignedCaseScreen({super.key});

  @override
  ConsumerState<AssignedCaseScreen> createState() =>
      _AssignedCaseScreenState();
}

class _AssignedCaseScreenState extends ConsumerState<AssignedCaseScreen> {
  final Set<String> _confirmed = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final casesAsync = ref.watch(casesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assigned Case',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        shape: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: casesAsync.when(
                loading: () => const _AcSkeleton(),
                error: (error, stackTrace) => EmptyState(
                  icon: Symbols.error,
                  title: 'Could not load your case',
                  subtitle:
                      'Check your connection and try again — queued work is safe.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(casesProvider),
                ),
                data: (cases) {
                  if (cases.isEmpty) {
                    return EmptyState(
                      icon: Symbols.assignment_ind,
                      title: 'No active assignment',
                      subtitle:
                          'You will be notified when the control room assigns a case.',
                      actionLabel: 'Refresh',
                      onAction: () => ref.invalidate(casesProvider),
                    );
                  }
                  final c = cases.firstWhere(
                    (e) => e['missing_person_name'] == 'Ramesh Kumar',
                    orElse: () => cases.first,
                  );
                  return _AcContent(
                    caseData: c,
                    confirmed: _confirmed,
                    onToggleItem: (item) => setState(() {
                      if (!_confirmed.remove(item)) _confirmed.add(item);
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _AcActionBar(
        onNavigate: () => _openMap(context),
        onFound: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FoundPersonFaceScanScreen()),
        ),
        onReportIssue: _showReportIssueSheet,
      ),
    );
  }

  void _openMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NavigationMapScreen()),
    );
  }

  Future<void> _showReportIssueSheet() async {
    final issue = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (sheetContext) => const _AcReportIssueSheet(),
    );
    if (issue == null || !mounted) return;
    await _submitIssue(issue);
  }

  Future<void> _submitIssue(String issue) async {
    final messenger = ScaffoldMessenger.of(context);
    final online = ref.read(isOnlineProvider);
    final body = {
      'case_id': 'KMP-2027-01042',
      'volunteer_id': 'vol-8842',
      'issue': issue,
      'reported_at': DateTime.now().toUtc().toIso8601String(),
    };

    var queued = false;
    if (online) {
      try {
        await ref
            .read(apiClientProvider)
            .post('/volunteers/vol-8842/issues', data: body);
      } catch (_) {
        queued = true;
      }
    } else {
      queued = true;
    }

    if (queued) {
      try {
        await ref.read(hiveServiceProvider).queueRequest(
              path: '/volunteers/vol-8842/issues',
              method: 'POST',
              body: body,
            );
      } catch (_) {
        // Optimistic UI regardless — the report stays visible to the user.
      }
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(queued
          ? 'Issue saved — will sync with the control room when online'
          : 'Issue reported to the control room'),
    ));
  }
}

// ---------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------

class _AcContent extends StatelessWidget {
  const _AcContent({
    required this.caseData,
    required this.confirmed,
    required this.onToggleItem,
  });

  final Map<String, dynamic> caseData;
  final Set<String> confirmed;
  final ValueChanged<String> onToggleItem;

  List<String> get _checklist {
    final items = <String>[];
    for (final key in ['physical_description', 'clothing_description']) {
      final raw = (caseData[key] as String?) ?? '';
      items.addAll(raw
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty));
    }
    final language = (caseData['language'] as String?) ?? '';
    if (language.isNotEmpty) items.add('Speaks $language');
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final checklist = _checklist;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutterMobile,
          AppSpacing.base, AppSpacing.gutterMobile, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AcPersonHeroCard(caseData: caseData)
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader('Identify by description',
                  icon: Symbols.checklist),
              _AcChecklistCard(
                items: checklist,
                confirmed: confirmed,
                onToggle: onToggleItem,
              ),
            ],
          ).animate(delay: 50.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader('Search zone', icon: Symbols.map),
              _AcMapPreviewCard(
                lastSeen: (caseData['last_seen_location'] as String?) ??
                    'Unknown location',
                onOpenMap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NavigationMapScreen()),
                ),
              ),
            ],
          ).animate(delay: 100.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06),
        ],
      ),
    );
  }
}

class _AcPersonHeroCard extends StatelessWidget {
  const _AcPersonHeroCard({required this.caseData});

  final Map<String, dynamic> caseData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (caseData['missing_person_name'] as String?) ?? 'Unknown';
    final caseId = (caseData['case_id'] as String?) ?? '—';
    final status = (caseData['status'] as String?) ?? 'Searching';
    final priority = (caseData['priority'] as String?) ?? 'High';
    final reportedRaw = caseData['reported_at'] as String?;
    final reportedAt =
        reportedRaw == null ? null : DateTime.tryParse(reportedRaw)?.toLocal();

    return AppCard(
      raised: true,
      accentColor: AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonAvatar(name, size: 72),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Text(
                        'CASE $caseId',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        StatusBadge.fromLabel(status),
                        PriorityBadge.fromLabel(priority),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          _AcInfoRow(
            icon: Symbols.calendar_month,
            label: 'Age band',
            value: (caseData['age_band'] as String?) ?? '—',
          ),
          const SizedBox(height: AppSpacing.sm),
          _AcInfoRow(
            icon: Symbols.wc,
            label: 'Gender',
            value: (caseData['gender'] as String?) ?? '—',
          ),
          const SizedBox(height: AppSpacing.sm),
          _AcInfoRow(
            icon: Symbols.location_on,
            label: 'Last seen',
            value: (caseData['last_seen_location'] as String?) ?? '—',
          ),
          if (reportedAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _AcInfoRow(
              icon: Symbols.schedule,
              label: 'Reported',
              value: DateFormat('d MMM, h:mm a').format(reportedAt),
            ),
          ],
        ],
      ),
    );
  }
}

class _AcInfoRow extends StatelessWidget {
  const _AcInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Checklist
// ---------------------------------------------------------------------------

class _AcChecklistCard extends StatelessWidget {
  const _AcChecklistCard({
    required this.items,
    required this.confirmed,
    required this.onToggle,
  });

  final List<String> items;
  final Set<String> confirmed;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = items.where(confirmed.contains).length;
    final progress = items.isEmpty ? 0.0 : done / items.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tap what matches the person you see',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Text(
                '$done/${items.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: AppColors.success,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final item in items)
                _AcCheckChip(
                  label: item,
                  checked: confirmed.contains(item),
                  onTap: () => onToggle(item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcCheckChip extends StatelessWidget {
  const _AcCheckChip({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.exit,
          curve: AppMotion.easeOut,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: checked
                ? AppColors.successContainer
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: checked
                  ? AppColors.success
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                checked ? Symbols.check_circle : Symbols.circle,
                size: 16,
                fill: checked ? 1 : 0,
                color: checked
                    ? AppColors.success
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: checked
                      ? AppColors.onSuccessContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map preview
// ---------------------------------------------------------------------------

class _AcMapPreviewCard extends StatelessWidget {
  const _AcMapPreviewCard({required this.lastSeen, required this.onOpenMap});

  final String lastSeen;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onOpenMap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 148,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.card)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Symbols.map,
                  size: 110,
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.dangerContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Symbols.location_on,
                          color: AppColors.danger, fill: 1),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      lastSeen,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentContainer,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.near_me,
                            size: 13, color: AppColors.onAccentContainer),
                        const SizedBox(width: 4),
                        Text(
                          '~850 m',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.onAccentContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search zone preview',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ETA 12 min on foot',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Symbols.open_in_full, size: 16),
                  label: const Text('Open map'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky action bar + report issue sheet
// ---------------------------------------------------------------------------

class _AcActionBar extends StatelessWidget {
  const _AcActionBar({
    required this.onNavigate,
    required this.onFound,
    required this.onReportIssue,
  });

  final VoidCallback onNavigate;
  final VoidCallback onFound;
  final VoidCallback onReportIssue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        boxShadow: AppShadows.raised,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryCta(
                label: 'Navigate',
                icon: Symbols.navigation,
                onPressed: onNavigate,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: PrimaryCta.tonal(
                      label: 'Found — Face Scan',
                      icon: Symbols.familiar_face_and_zone,
                      onPressed: onFound,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _AcDangerTonalButton(
                      label: 'Report issue',
                      icon: Symbols.report,
                      onPressed: onReportIssue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcDangerTonalButton extends StatelessWidget {
  const _AcDangerTonalButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadius.button));
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.dangerContainer,
        borderRadius: radius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onDangerContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, size: 20, color: AppColors.onDangerContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AcReportIssueSheet extends StatelessWidget {
  const _AcReportIssueSheet();

  static const _issues = [
    (icon: Symbols.directions_off, label: "Can't continue the search"),
    (icon: Symbols.medical_services, label: 'Need medical assistance'),
    (icon: Symbols.location_off, label: 'Person not at last seen location'),
    (icon: Symbols.help, label: 'Other issue — contact control room'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, 0, AppSpacing.base, AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report an issue',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The control room is notified immediately — or queued offline.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.base),
            for (final issue in _issues)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(issue.label),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(issue.icon,
                              size: 20, color: AppColors.danger),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              issue.label,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(Symbols.chevron_right,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _AcSkeleton extends StatelessWidget {
  const _AcSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.gutterMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShimmerBox(height: 220, radius: AppRadius.card),
          SizedBox(height: AppSpacing.xl),
          ShimmerBox(width: 180, height: 18),
          SizedBox(height: AppSpacing.md),
          ShimmerBox(height: 150, radius: AppRadius.card),
          SizedBox(height: AppSpacing.xl),
          ShimmerBox(width: 140, height: 18),
          SizedBox(height: AppSpacing.md),
          ShimmerBox(height: 200, radius: AppRadius.card),
        ],
      ),
    );
  }
}

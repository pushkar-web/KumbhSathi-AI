import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/animated_count.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';

/// Task History — DESIGN.md §6.3. Month filter, animated impact summary and
/// a timeline of completed tasks with outcome pills and relative dates.
class TaskHistoryScreen extends StatefulWidget {
  const TaskHistoryScreen({super.key});

  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  bool _loading = true;
  String _selectedMonth = 'All';
  late final List<_ThTask> _tasks;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tasks = [
      _ThTask(
        title: 'Face match confirmed',
        caseId: 'KMP-2027-00940',
        detail: 'Sita Devi found at the Sector 3 tent and reunited '
            'with her family at the help desk.',
        outcome: _ThOutcome.reunited,
        when: now.subtract(const Duration(hours: 2, minutes: 10)),
      ),
      _ThTask(
        title: 'CCTV observation verified',
        caseId: 'KMP-2027-00812',
        detail: 'Verified an AI-suggested match at Chokepoint B and '
            'escorted the pilgrim to the police kiosk.',
        outcome: _ThOutcome.matched,
        when: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      _ThTask(
        title: 'Supply check completed',
        caseId: 'LOG-2027-00218',
        detail: 'Confirmed delivery of water rations at the Sector 4 '
            'medical camp.',
        outcome: _ThOutcome.completed,
        when: now.subtract(const Duration(days: 3, hours: 5)),
      ),
      _ThTask(
        title: 'Search sweep — Sector 2',
        caseId: 'KMP-2027-00761',
        detail: 'Swept the dormitory rows without a sighting; case '
            'escalated to the police search team.',
        outcome: _ThOutcome.escalated,
        when: now.subtract(const Duration(days: 9, hours: 2)),
      ),
      _ThTask(
        title: 'Family reunion assisted',
        caseId: 'KMP-2027-00644',
        detail: 'Guided an elderly pilgrim from the transit gate back to '
            'his group; identity confirmed on the spot.',
        outcome: _ThOutcome.reunited,
        when: now.subtract(const Duration(days: 14, hours: 6)),
      ),
      _ThTask(
        title: 'Crowd assist — Ghat 6',
        caseId: 'LOG-2027-00187',
        detail: 'Managed the queue rail during the evening aarti rush '
            'with zero incidents.',
        outcome: _ThOutcome.completed,
        when: now.subtract(const Duration(days: 21, hours: 1)),
      ),
    ];
    Future<void>.delayed(const Duration(milliseconds: 550)).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  List<String> get _months {
    final seen = <String>[];
    for (final t in _tasks) {
      final m = DateFormat('MMMM').format(t.when);
      if (!seen.contains(m)) seen.add(m);
    }
    return ['All', ...seen];
  }

  List<_ThTask> get _filtered => _selectedMonth == 'All'
      ? _tasks
      : _tasks
          .where((t) => DateFormat('MMMM').format(t.when) == _selectedMonth)
          .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: _loading ? const _ThSkeleton() : _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final tasks = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutterMobile,
          AppSpacing.base, AppSpacing.gutterMobile, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ThHeader()
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.base),
          _ThMonthFilter(
            months: _months,
            selected: _selectedMonth,
            onSelect: (m) => setState(() => _selectedMonth = m),
          ).animate(delay: 50.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.base),
          const _ThImpactSummaryCard()
              .animate(delay: 100.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.xl),
          if (tasks.isEmpty)
            EmptyState(
              icon: Symbols.history,
              title: 'No tasks in $_selectedMonth',
              subtitle: 'Try another month or view your full history.',
              actionLabel: 'Show all',
              onAction: () => setState(() => _selectedMonth = 'All'),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tasks.length; i++)
                  _ThTimelineRow(
                    task: tasks[i],
                    isLast: i == tasks.length - 1,
                  )
                      .animate(delay: (150 + (i < 6 ? i : 5) * 50).ms)
                      .fadeIn(duration: 240.ms)
                      .slideY(begin: 0.06),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header + month filter
// ---------------------------------------------------------------------------

class _ThHeader extends StatelessWidget {
  const _ThHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task History',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Your seva impact this Kumbh',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const AiModeChip(dense: true),
      ],
    );
  }
}

class _ThMonthFilter extends StatelessWidget {
  const _ThMonthFilter({
    required this.months,
    required this.selected,
    required this.onSelect,
  });

  final List<String> months;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final month in months)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () => onSelect(month),
                  child: AnimatedContainer(
                    duration: AppMotion.exit,
                    curve: AppMotion.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base, vertical: 10),
                    decoration: BoxDecoration(
                      color: month == selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: month == selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      month,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: month == selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Impact summary
// ---------------------------------------------------------------------------

class _ThImpactSummaryCard extends StatelessWidget {
  const _ThImpactSummaryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IMPACT SUMMARY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          IntrinsicHeight(
            child: Row(
              children: [
                const Expanded(
                  child: _ThStat(value: 12, label: 'Cases\nresolved'),
                ),
                Container(width: 1, color: theme.colorScheme.outlineVariant),
                const Expanded(
                  child: _ThStat(value: 25, label: 'Tasks\ncompleted'),
                ),
                Container(width: 1, color: theme.colorScheme.outlineVariant),
                const Expanded(
                  child:
                      _ThStat(value: 32, suffix: 'h', label: 'Active\nhours'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThStat extends StatelessWidget {
  const _ThStat({required this.value, required this.label, this.suffix = ''});

  final num value;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: [
          AnimatedCount(
            value,
            suffix: suffix,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

enum _ThOutcome { reunited, matched, completed, escalated }

class _ThTask {
  const _ThTask({
    required this.title,
    required this.caseId,
    required this.detail,
    required this.outcome,
    required this.when,
  });

  final String title;
  final String caseId;
  final String detail;
  final _ThOutcome outcome;
  final DateTime when;
}

({String label, IconData icon, Color fg, Color bg}) _thOutcomeStyle(
    _ThOutcome o) {
  return switch (o) {
    _ThOutcome.reunited => (
        label: 'Reunited',
        icon: Symbols.check_circle,
        fg: AppColors.success,
        bg: AppColors.successContainer,
      ),
    _ThOutcome.matched => (
        label: 'Matched',
        icon: Symbols.familiar_face_and_zone,
        fg: AppColors.primary,
        bg: AppColors.primaryContainer,
      ),
    _ThOutcome.completed => (
        label: 'Completed',
        icon: Symbols.task_alt,
        fg: AppColors.info,
        bg: AppColors.infoContainer,
      ),
    _ThOutcome.escalated => (
        label: 'Escalated',
        icon: Symbols.warning,
        fg: AppColors.warning,
        bg: AppColors.warningContainer,
      ),
  };
}

String _thRelative(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24 && now.day == t.day) {
    return 'Today, ${DateFormat('h:mm a').format(t)}';
  }
  if (diff.inDays < 2) return 'Yesterday, ${DateFormat('h:mm a').format(t)}';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('d MMM, h:mm a').format(t);
}

class _ThTimelineRow extends StatelessWidget {
  const _ThTimelineRow({required this.task, required this.isLast});

  final _ThTask task;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _thOutcomeStyle(task.outcome);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: style.fg,
                    shape: BoxShape.circle,
                    border: Border.all(color: style.bg, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: AppSpacing.xs),
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _ThOutcomePill(style: style),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(Symbols.schedule,
                          size: 14, color: AppColors.inkFaint),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _thRelative(task.when),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.inkFaint),
                      ),
                      const Spacer(),
                      Text(
                        task.caseId,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.inkFaint,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThOutcomePill extends StatelessWidget {
  const _ThOutcomePill({required this.style});

  final ({String label, IconData icon, Color fg, Color bg}) style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.fg),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: style.fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _ThSkeleton extends StatelessWidget {
  const _ThSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.gutterMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 180, height: 26),
          SizedBox(height: AppSpacing.base),
          Row(
            children: [
              ShimmerBox(width: 64, height: 38, radius: AppRadius.pill),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 88, height: 38, radius: AppRadius.pill),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 88, height: 38, radius: AppRadius.pill),
            ],
          ),
          SizedBox(height: AppSpacing.base),
          ShimmerBox(height: 128, radius: AppRadius.card),
          SizedBox(height: AppSpacing.xl),
          ShimmerList(items: 4, itemHeight: 124),
        ],
      ),
    );
  }
}

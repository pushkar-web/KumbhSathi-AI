import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import 'assigned_case_screen.dart';
import 'found_person_face_scan.dart';
import 'navigation_map_screen.dart';

/// Recent Assignments — dedicated volunteer tab showing active + past
/// assignments. Fixes the overlapping issue from the dashboard by giving
/// assignments their own page with filtering and full detail.
class RecentAssignmentsScreen extends StatefulWidget {
  const RecentAssignmentsScreen({super.key});

  @override
  State<RecentAssignmentsScreen> createState() =>
      _RecentAssignmentsScreenState();
}

class _RecentAssignmentsScreenState extends State<RecentAssignmentsScreen> {
  bool _loading = true;
  String _filter = 'All';

  static const _filters = ['All', 'Active', 'Completed', 'Escalated'];

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 500)).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: _loading ? const _RasSkeleton() : _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final assignments = _filteredAssignments();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutterMobile,
          AppSpacing.base, AppSpacing.gutterMobile, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _RasHeader()
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.base),
          _RasFilterChips(
            filters: _filters,
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ).animate(delay: 50.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.lg),

          // Active assignment — prominent card
          if (_filter == 'All' || _filter == 'Active') ...[
            const SectionHeader(
              'Active Assignment',
              icon: Symbols.assignment_ind,
            ).animate(delay: 100.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06),
            _RasActiveCard(
              onNavigate: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const NavigationMapScreen()),
              ),
              onFound: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const FoundPersonFaceScanScreen()),
              ),
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AssignedCaseScreen()),
              ),
            )
                .animate(delay: 150.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Past assignments
          const SectionHeader(
            'Past Assignments',
            icon: Symbols.history,
          ).animate(delay: 200.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06),

          if (assignments.isEmpty)
            EmptyState(
              icon: Symbols.assignment,
              title: 'No assignments found',
              subtitle: _filter == 'All'
                  ? 'You have no past assignments yet.'
                  : 'No $_filter assignments to show.',
              actionLabel: _filter != 'All' ? 'Show all' : null,
              onAction:
                  _filter != 'All' ? () => setState(() => _filter = 'All') : null,
            )
          else
            Column(
              children: [
                for (var i = 0; i < assignments.length; i++)
                  _RasTimelineRow(
                    assignment: assignments[i],
                    isLast: i == assignments.length - 1,
                  )
                      .animate(delay: (250 + (i < 6 ? i : 5) * 50).ms)
                      .fadeIn(duration: 240.ms)
                      .slideY(begin: 0.06),
              ],
            ),
        ],
      ),
    );
  }

  List<_RasAssignment> _filteredAssignments() {
    final all = _rasPastAssignments;
    if (_filter == 'All') return all;
    return all
        .where((a) => a.outcome.label == _filter)
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _RasHeader extends StatelessWidget {
  const _RasHeader();

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
                'My Assignments',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Track all your case assignments',
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

// ---------------------------------------------------------------------------
// Filter chips
// ---------------------------------------------------------------------------

class _RasFilterChips extends StatelessWidget {
  const _RasFilterChips({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () => onSelect(f),
                  child: AnimatedContainer(
                    duration: AppMotion.exit,
                    curve: AppMotion.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base, vertical: 10),
                    decoration: BoxDecoration(
                      color: f == selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: f == selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      f,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: f == selected
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
// Active assignment card
// ---------------------------------------------------------------------------

class _RasActiveCard extends StatelessWidget {
  const _RasActiveCard({
    required this.onNavigate,
    required this.onFound,
    required this.onOpen,
  });

  final VoidCallback onNavigate;
  final VoidCallback onFound;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      accentColor: AppColors.accent,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusBadge.fromLabel('Searching'),
              const SizedBox(width: AppSpacing.sm),
              const PriorityBadge.fromLabel('High'),
              const Spacer(),
              Text(
                'KMP-2027-01042',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PersonAvatar('Ramesh Kumar', size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ramesh Kumar',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _RasMetaChip(
                          icon: Symbols.calendar_month,
                          label: 'Age 72',
                          fg: theme.colorScheme.onSurfaceVariant,
                          bg: theme.colorScheme.surfaceContainerHigh,
                        ),
                        const _RasMetaChip(
                          icon: Symbols.near_me,
                          label: '~850 m away',
                          fg: AppColors.onAccentContainer,
                          bg: AppColors.accentContainer,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAST SEEN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Symbols.location_on,
                        size: 16, color: AppColors.danger, fill: 1),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Madsangvi Transit Gate · 25 min ago',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                child: PrimaryCta(
                  label: 'Navigate',
                  icon: Symbols.navigation,
                  onPressed: onNavigate,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryCta.tonal(
            label: 'Found — Scan Face',
            icon: Symbols.familiar_face_and_zone,
            onPressed: onFound,
          ),
        ],
      ),
    );
  }
}

class _RasMetaChip extends StatelessWidget {
  const _RasMetaChip({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Past assignment data & timeline
// ---------------------------------------------------------------------------

enum _RasOutcome {
  completed('Completed'),
  escalated('Escalated'),
  active('Active');

  const _RasOutcome(this.label);
  final String label;
}

class _RasAssignment {
  const _RasAssignment({
    required this.personName,
    required this.caseId,
    required this.detail,
    required this.outcome,
    required this.when,
    required this.sector,
  });

  final String personName;
  final String caseId;
  final String detail;
  final _RasOutcome outcome;
  final DateTime when;
  final String sector;
}

final List<_RasAssignment> _rasPastAssignments = [
  _RasAssignment(
    personName: 'Sita Devi',
    caseId: 'KMP-2027-00940',
    detail: 'Found at the Sector 3 tent and reunited with her family at the help desk.',
    outcome: _RasOutcome.completed,
    when: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
    sector: 'Sector 3',
  ),
  _RasAssignment(
    personName: 'Mohan Lal',
    caseId: 'KMP-2027-00812',
    detail: 'AI-suggested match at Chokepoint B verified; pilgrim escorted to police kiosk.',
    outcome: _RasOutcome.completed,
    when: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    sector: 'Sector 2',
  ),
  _RasAssignment(
    personName: 'Priya Sharma',
    caseId: 'KMP-2027-00761',
    detail: 'Dormitory sweep in Sector 2 without sighting; case escalated to police search team.',
    outcome: _RasOutcome.escalated,
    when: DateTime.now().subtract(const Duration(days: 3, hours: 5)),
    sector: 'Sector 2',
  ),
  _RasAssignment(
    personName: 'Raju Verma',
    caseId: 'KMP-2027-00644',
    detail: 'Elderly pilgrim guided from transit gate back to his group; identity confirmed.',
    outcome: _RasOutcome.completed,
    when: DateTime.now().subtract(const Duration(days: 9, hours: 2)),
    sector: 'Sector 4',
  ),
  _RasAssignment(
    personName: 'Anita Gupta',
    caseId: 'KMP-2027-00581',
    detail: 'Located near the medical camp with disorientation; transferred to hospital team.',
    outcome: _RasOutcome.escalated,
    when: DateTime.now().subtract(const Duration(days: 14, hours: 6)),
    sector: 'Sector 1',
  ),
];

({String label, IconData icon, Color fg, Color bg}) _rasOutcomeStyle(
    _RasOutcome o) {
  return switch (o) {
    _RasOutcome.completed => (
        label: 'Completed',
        icon: Symbols.check_circle,
        fg: AppColors.success,
        bg: AppColors.successContainer,
      ),
    _RasOutcome.escalated => (
        label: 'Escalated',
        icon: Symbols.warning,
        fg: AppColors.warning,
        bg: AppColors.warningContainer,
      ),
    _RasOutcome.active => (
        label: 'Active',
        icon: Symbols.radio_button_checked,
        fg: AppColors.accent,
        bg: AppColors.accentContainer,
      ),
  };
}

String _rasRelative(DateTime t) {
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

class _RasTimelineRow extends StatelessWidget {
  const _RasTimelineRow({required this.assignment, required this.isLast});

  final _RasAssignment assignment;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _rasOutcomeStyle(assignment.outcome);

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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AssignedCaseScreen()),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PersonAvatar(assignment.personName, size: 36),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.personName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              assignment.sector,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      _RasOutcomePill(style: style),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    assignment.detail,
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
                        _rasRelative(assignment.when),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.inkFaint),
                      ),
                      const Spacer(),
                      Text(
                        assignment.caseId,
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

class _RasOutcomePill extends StatelessWidget {
  const _RasOutcomePill({required this.style});

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

class _RasSkeleton extends StatelessWidget {
  const _RasSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.gutterMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 200, height: 26),
          SizedBox(height: AppSpacing.base),
          Row(
            children: [
              ShimmerBox(width: 64, height: 38, radius: AppRadius.pill),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 88, height: 38, radius: AppRadius.pill),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 100, height: 38, radius: AppRadius.pill),
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          ShimmerBox(height: 240, radius: AppRadius.card),
          SizedBox(height: AppSpacing.xl),
          ShimmerList(items: 3, itemHeight: 140),
        ],
      ),
    );
  }
}

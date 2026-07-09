import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../shared/widgets/animated_count.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/status_badge.dart';
import 'case_detail_screen.dart';

/// Police command dashboard (DESIGN.md §6.2) — Design System v2 "Sanctum".
///
/// The app shell already provides the NavigationRail, so this screen renders
/// only the topbar + scrollable content: KPI row with sparklines, recent-cases
/// table + Live AI Alerts panel, and a charts row (status donut + 7-day area).
class PoliceDashboardScreen extends ConsumerWidget {
  const PoliceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const _PoliceDashTopBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= AppBreakpoints.desktop;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide
                        ? AppSpacing.gutterDesktop
                        : AppSpacing.gutterMobile,
                    vertical: AppSpacing.xl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: AppSpacing.contentMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PoliceDashKpiRow(wide: wide),
                          const SizedBox(height: AppSpacing.xl),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: const _PoliceDashCasesTable()
                                      .animate(delay: 200.ms)
                                      .fadeIn(duration: 240.ms)
                                      .slideY(begin: 0.06),
                                ),
                                const SizedBox(width: AppSpacing.xl),
                                Expanded(
                                  child: const _PoliceDashAlertsPanel()
                                      .animate(delay: 250.ms)
                                      .fadeIn(duration: 240.ms)
                                      .slideY(begin: 0.06),
                                ),
                              ],
                            )
                          else ...[
                            const _PoliceDashCasesTable()
                                .animate(delay: 200.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06),
                            const SizedBox(height: AppSpacing.xl),
                            const _PoliceDashAlertsPanel()
                                .animate(delay: 250.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: const _PoliceDashStatusDonutCard()
                                      .animate(delay: 300.ms)
                                      .fadeIn(duration: 240.ms)
                                      .slideY(begin: 0.06),
                                ),
                                const SizedBox(width: AppSpacing.xl),
                                Expanded(
                                  child: const _PoliceDashReportsTrendCard()
                                      .animate(delay: 350.ms)
                                      .fadeIn(duration: 240.ms)
                                      .slideY(begin: 0.06),
                                ),
                              ],
                            )
                          else ...[
                            const _PoliceDashStatusDonutCard()
                                .animate(delay: 300.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06),
                            const SizedBox(height: AppSpacing.xl),
                            const _PoliceDashReportsTrendCard()
                                .animate(delay: 350.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _policeDashTimeAgo(Object? iso) {
  final dt = iso is String ? DateTime.tryParse(iso) : null;
  if (dt == null) return '—';
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

int _policeDashInt(Object? v) => v is num ? v.toInt() : 0;

void _policeDashNotify(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

// ---------------------------------------------------------------------------
// Topbar
// ---------------------------------------------------------------------------

class _PoliceDashTopBar extends ConsumerWidget {
  const _PoliceDashTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authStateProvider).user;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showSearch = constraints.maxWidth >= 860;
          return Row(
            children: [
              if (showSearch) ...[
                SizedBox(
                  width: 360,
                  child: TextField(
                    onSubmitted: (q) => _policeDashNotify(
                        context, 'Searching cases for "$q"…'),
                    decoration: InputDecoration(
                      hintText: 'Search cases, IDs, names…',
                      prefixIcon: const Icon(Symbols.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Officer Command Center',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const AiModeChip(),
              const SizedBox(width: AppSpacing.sm),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () =>
                        _policeDashNotify(context, 'No new notifications'),
                    icon: const Icon(Symbols.notifications),
                  ),
                  Positioned(
                    top: 8,
                    right: 10,
                    child: IgnorePointer(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: scheme.surface, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              PersonAvatar(
                user?.fullName ?? 'Officer',
                size: 40,
                statusDot: AppColors.success,
              ),
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06);
  }
}

// ---------------------------------------------------------------------------
// Row 1 — KPI cards
// ---------------------------------------------------------------------------

class _PoliceDashKpiRow extends ConsumerWidget {
  const _PoliceDashKpiRow({required this.wide});

  final bool wide;

  static const List<double> _sparkActive = [14, 18, 16, 22, 19, 25, 23];
  static const List<double> _sparkReunited = [180, 210, 196, 238, 262, 255, 291];
  static const List<double> _sparkCritical = [34, 31, 36, 29, 27, 30, 24];
  static const List<double> _sparkAvg = [5.1, 4.8, 5.0, 4.6, 4.4, 4.5, 4.2];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpi = ref.watch(dashboardKpiProvider);
    return kpi.when(
      loading: () => _PoliceDashKpiGrid(
        wide: wide,
        children: const [
          ShimmerBox(height: 172, radius: AppRadius.card),
          ShimmerBox(height: 172, radius: AppRadius.card),
          ShimmerBox(height: 172, radius: AppRadius.card),
          ShimmerBox(height: 172, radius: AppRadius.card),
        ],
      ),
      error: (e, _) => AppCard(
        child: EmptyState(
          icon: Symbols.monitoring,
          title: 'Metrics unavailable',
          subtitle: 'Command metrics could not be loaded right now.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(dashboardKpiProvider),
        ),
      ),
      data: (data) {
        final status =
            Map<String, dynamic>.from(data['status_counts'] as Map? ?? {});
        final priority =
            Map<String, dynamic>.from(data['priority_counts'] as Map? ?? {});
        final active = _policeDashInt(status['Pending']) +
            _policeDashInt(status['Searching']);
        final reunited = _policeDashInt(status['Reunited']);
        final critical = _policeDashInt(priority['Critical']);
        final avgHours =
            (data['avg_resolution_hours'] as num?)?.toDouble() ?? 0;

        final cards = <Widget>[
          KpiCard(
            label: 'Active & pending cases',
            value: active,
            icon: Symbols.person_search,
            color: AppColors.primary,
            containerColor: AppColors.primaryContainer,
            deltaLabel: '+3.2% today',
            deltaPositive: true,
            sparkline: _sparkActive,
          ),
          KpiCard(
            label: 'Reunited',
            value: reunited,
            icon: Symbols.diversity_1,
            color: AppColors.success,
            containerColor: AppColors.successContainer,
            deltaLabel: '+12% this wk',
            deltaPositive: true,
            sparkline: _sparkReunited,
          ),
          KpiCard(
            label: 'Critical priority',
            value: critical,
            icon: Symbols.warning,
            color: AppColors.danger,
            containerColor: AppColors.dangerContainer,
            deltaLabel: '-8% this wk',
            deltaPositive: false,
            sparkline: _sparkCritical,
          ),
          KpiCard(
            label: 'Avg resolution',
            value: avgHours,
            suffix: 'h',
            decimals: 1,
            icon: Symbols.timer,
            color: AppColors.info,
            containerColor: AppColors.infoContainer,
            deltaLabel: '-0.4h this wk',
            deltaPositive: false,
            sparkline: _sparkAvg,
          ),
        ];

        return _PoliceDashKpiGrid(
          wide: wide,
          children: [
            for (var i = 0; i < cards.length; i++)
              cards[i]
                  .animate(delay: (i * 50).ms)
                  .fadeIn(duration: 240.ms)
                  .slideY(begin: 0.06),
          ],
        );
      },
    );
  }
}

/// Lays out exactly four KPI tiles: 4-up when wide, 2x2 otherwise.
class _PoliceDashKpiGrid extends StatelessWidget {
  const _PoliceDashKpiGrid({required this.wide, required this.children});

  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: children[1]),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: children[2]),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: children[3]),
          ],
        ),
      );
    }
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: AppSpacing.base),
              Expanded(child: children[1]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[2]),
              const SizedBox(width: AppSpacing.base),
              Expanded(child: children[3]),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Row 2 — Recent cases table
// ---------------------------------------------------------------------------

class _PoliceDashCasesTable extends ConsumerWidget {
  const _PoliceDashCasesTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cases = ref.watch(casesProvider);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
            child: Row(
              children: [
                const Icon(Symbols.format_list_bulleted,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Recent Cases',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Tap a row to open the case file',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          cases.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.base),
              child: ShimmerList(items: 4, itemHeight: 56),
            ),
            error: (e, _) => EmptyState(
              icon: Symbols.error,
              title: 'Cases could not be loaded',
              subtitle: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(casesProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Symbols.folder_open,
                  title: 'No cases yet',
                  subtitle: 'Newly reported cases will appear here.',
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      columnSpacing: AppSpacing.base,
                      horizontalMargin: AppSpacing.lg,
                      headingRowHeight: 44,
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 64,
                      dividerThickness: 0.6,
                      headingRowColor: WidgetStatePropertyAll(
                        scheme.surfaceContainerHigh.withValues(alpha: 0.55),
                      ),
                      headingTextStyle: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                      columns: const [
                        DataColumn(label: Text('CASE ID')),
                        DataColumn(label: Text('PERSON')),
                        DataColumn(label: Text('AGE')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('PRIORITY')),
                        DataColumn(label: Text('LAST SEEN')),
                        DataColumn(label: Text('REPORTED')),
                      ],
                      rows: [
                        for (final c in list) _row(context, theme, c),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  DataRow _row(
      BuildContext context, ThemeData theme, Map<String, dynamic> data) {
    final scheme = theme.colorScheme;
    final name = (data['missing_person_name'] as String?) ?? 'Unknown';
    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.hovered)
            ? AppColors.primary.withValues(alpha: 0.05)
            : null,
      ),
      onSelectChanged: (_) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CaseDetailScreen(caseData: data),
          ),
        );
      },
      cells: [
        DataCell(Text(
          (data['case_id'] as String?) ?? '—',
          style: theme.textTheme.labelMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        )),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonAvatar(name, size: 32),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        )),
        DataCell(Text(
          (data['age_band'] as String?) ?? '—',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        )),
        DataCell(StatusBadge.fromLabel((data['status'] as String?) ?? '')),
        DataCell(PriorityBadge.fromLabel((data['priority'] as String?) ?? '')),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            (data['last_seen_location'] as String?) ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        )),
        DataCell(Text(
          _policeDashTimeAgo(data['reported_at']),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Row 2 — Live AI Alerts panel
// ---------------------------------------------------------------------------

class _PoliceDashAlertsPanel extends StatelessWidget {
  const _PoliceDashAlertsPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 1, end: 0.3, duration: 700.ms),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Live AI Alerts',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const _PoliceDashAlertCard(
          icon: Symbols.content_copy,
          color: AppColors.info,
          container: AppColors.infoContainer,
          tag: 'New',
          title: 'Duplicate detected',
          body:
              'KMP-2027-02418 matches KMP-2027-02391 — 92% profile similarity, both reported near Sector 4 Ghats.',
          primaryAction: 'Review match',
          secondaryAction: 'Dismiss',
        ),
        const SizedBox(height: AppSpacing.md),
        const _PoliceDashAlertCard(
          icon: Symbols.face,
          color: AppColors.success,
          container: AppColors.successContainer,
          tag: '87%',
          title: 'Face match found',
          body:
              '87% confidence match for KMP-2027-02502 spotted on CCTV Feed-3, Sector 2 Dormitories, 4 min ago.',
          primaryAction: 'Open match',
          secondaryAction: 'Later',
        ),
        const SizedBox(height: AppSpacing.md),
        const _PoliceDashAlertCard(
          icon: Symbols.priority_high,
          color: AppColors.danger,
          container: AppColors.dangerContainer,
          tag: 'Critical',
          title: 'Priority escalation',
          body:
              'KMP-2027-02501 (child, age band 0-12) has breached the 2-hour first-response SLA. Immediate action advised.',
          primaryAction: 'Escalate now',
          secondaryAction: 'Assign officer',
        ),
      ],
    );
  }
}

class _PoliceDashAlertCard extends StatelessWidget {
  const _PoliceDashAlertCard({
    required this.icon,
    required this.color,
    required this.container,
    required this.tag,
    required this.title,
    required this.body,
    required this.primaryAction,
    required this.secondaryAction,
  });

  final IconData icon;
  final Color color;
  final Color container;
  final String tag;
  final String title;
  final String body;
  final String primaryAction;
  final String secondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: container,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: container,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  tag,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              FilledButton(
                onPressed: () => _policeDashNotify(
                    context, '$primaryAction queued — will sync'),
                style: FilledButton.styleFrom(
                  backgroundColor: container,
                  foregroundColor: color,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base),
                  textStyle: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                child: Text(primaryAction),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () =>
                    _policeDashNotify(context, '$secondaryAction noted'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md),
                ),
                child: Text(secondaryAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row 3 — Status donut
// ---------------------------------------------------------------------------

class _PoliceDashStatusDonutCard extends ConsumerWidget {
  const _PoliceDashStatusDonutCard();

  static const List<({String label, Color color})> _slices = [
    (label: 'Pending', color: AppColors.warning),
    (label: 'Searching', color: AppColors.accent),
    (label: 'Reunited', color: AppColors.success),
    (label: 'Transferred to hospital', color: AppColors.hospital),
    (label: 'Unresolved', color: AppColors.danger),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kpi = ref.watch(dashboardKpiProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.donut_large,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Case Status Mix',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          kpi.when(
            loading: () =>
                const ShimmerBox(height: 248, radius: AppRadius.card),
            error: (e, _) => EmptyState(
              icon: Symbols.donut_large,
              title: 'Chart unavailable',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(dashboardKpiProvider),
            ),
            data: (data) {
              final status = Map<String, dynamic>.from(
                  data['status_counts'] as Map? ?? {});
              final counts = [
                for (final s in _slices) _policeDashInt(status[s.label]),
              ];
              final total = counts.fold<int>(0, (a, b) => a + b);
              if (total == 0) {
                return const EmptyState(
                  icon: Symbols.donut_large,
                  title: 'No case data yet',
                  subtitle: 'Status distribution appears once cases exist.',
                );
              }
              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Stack(
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 58,
                            startDegreeOffset: -90,
                            pieTouchData: PieTouchData(enabled: false),
                            sections: [
                              for (var i = 0; i < _slices.length; i++)
                                if (counts[i] > 0)
                                  PieChartSectionData(
                                    value: counts[i].toDouble(),
                                    color: _slices[i].color,
                                    radius: 26,
                                    showTitle: false,
                                  ),
                            ],
                          ),
                          duration: AppMotion.enter,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedCount(
                                total,
                                style: theme.textTheme.headlineMedium,
                              ),
                              Text(
                                'total cases',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.base,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (var i = 0; i < _slices.length; i++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _slices[i].color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _slices[i].label == 'Transferred to hospital'
                                  ? 'Hospital'
                                  : _slices[i].label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(width: 6),
                            AnimatedCount(
                              counts[i],
                              style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row 3 — 7-day reports trend
// ---------------------------------------------------------------------------

class _PoliceDashReportsTrendCard extends StatelessWidget {
  const _PoliceDashReportsTrendCard();

  static const List<double> _reports = [26, 34, 31, 42, 38, 47, 41];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final dayLabels = [
      for (var i = 6; i >= 0; i--)
        DateFormat.E().format(now.subtract(Duration(days: i))),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.show_chart,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Reports — Last 7 Days',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'daily new cases',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 232,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                minY: 0,
                maxY: 60,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= dayLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            dayLabels[i],
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < _reports.length; i++)
                        FlSpot(i.toDouble(), _reports[i]),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.18),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: AppMotion.enter,
            ),
          ),
        ],
      ),
    );
  }
}

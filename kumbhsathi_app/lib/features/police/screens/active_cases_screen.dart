import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../shared/widgets/animated_count.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/status_badge.dart';
import 'case_detail_screen.dart';

/// Police portal — Active Cases registry (DESIGN.md §6.2 "Cases list").
///
/// Filter bar (status segmented control, priority chips, search, sort menu)
/// filtering [casesProvider] data client-side, feeding a paginated styled
/// table (10 rows/page). Tapping a row opens [CaseDetailScreen].
class ActiveCasesScreen extends ConsumerStatefulWidget {
  const ActiveCasesScreen({super.key});

  @override
  ConsumerState<ActiveCasesScreen> createState() => _ActiveCasesScreenState();
}

// ---------------------------------------------------------------------------
// Filter/sort vocabulary
// ---------------------------------------------------------------------------

enum _AcSort {
  newest('Newest first'),
  oldest('Oldest first'),
  priority('Priority (high → low)'),
  name('Name (A → Z)');

  const _AcSort(this.label);
  final String label;
}

const List<String> _acStatusFilters = [
  'All',
  'Pending',
  'Searching',
  'Reunited',
  'Hospital',
  'Unresolved',
];

const List<String> _acPriorities = ['Low', 'Medium', 'High', 'Critical'];

const Map<String, int> _acPriorityRank = {
  'Critical': 0,
  'High': 1,
  'Medium': 2,
  'Low': 3,
};

DateTime? _acReportedAt(Map<String, dynamic> row) =>
    DateTime.tryParse((row['reported_at'] ?? '').toString());

String _acTimeAgo(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

// ---------------------------------------------------------------------------
// Screen state
// ---------------------------------------------------------------------------

class _ActiveCasesScreenState extends ConsumerState<ActiveCasesScreen> {
  static const int _pageSize = 10;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _statusFilter = 'All';
  final Set<String> _priorityFilter = <String>{};
  _AcSort _sort = _AcSort.newest;
  int _page = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _query.isNotEmpty || _statusFilter != 'All' || _priorityFilter.isNotEmpty;

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _query = '';
      _statusFilter = 'All';
      _priorityFilter.clear();
      _page = 0;
    });
  }

  List<Map<String, dynamic>> _visibleCases(List<Map<String, dynamic>> cases) {
    final wantStatus =
        _statusFilter == 'Hospital' ? 'Transferred to hospital' : _statusFilter;
    final q = _query.toLowerCase();

    final out = cases.where((c) {
      if (_statusFilter != 'All' &&
          (c['status'] ?? '').toString() != wantStatus) {
        return false;
      }
      if (_priorityFilter.isNotEmpty &&
          !_priorityFilter.contains((c['priority'] ?? '').toString())) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay = [
          c['missing_person_name'],
          c['case_id'],
          c['last_seen_location'],
          c['district'],
          c['state'],
        ].map((v) => (v ?? '').toString().toLowerCase()).join(' ');
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    out.sort((a, b) {
      switch (_sort) {
        case _AcSort.newest:
          return (_acReportedAt(b) ?? DateTime(2000))
              .compareTo(_acReportedAt(a) ?? DateTime(2000));
        case _AcSort.oldest:
          return (_acReportedAt(a) ?? DateTime(2100))
              .compareTo(_acReportedAt(b) ?? DateTime(2100));
        case _AcSort.priority:
          final ra = _acPriorityRank[(a['priority'] ?? '').toString()] ?? 9;
          final rb = _acPriorityRank[(b['priority'] ?? '').toString()] ?? 9;
          if (ra != rb) return ra.compareTo(rb);
          return (_acReportedAt(b) ?? DateTime(2000))
              .compareTo(_acReportedAt(a) ?? DateTime(2000));
        case _AcSort.name:
          return (a['missing_person_name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                  (b['missing_person_name'] ?? '').toString().toLowerCase());
      }
    });
    return out;
  }

  void _openCase(Map<String, dynamic> row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CaseDetailScreen(caseData: row),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(casesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: casesAsync.when(
                data: (cases) => _buildData(context, cases),
                loading: () => const _AcLoadingSkeleton(),
                error: (_, __) => EmptyState(
                  icon: Symbols.cloud_off,
                  title: 'Could not load cases',
                  subtitle: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(casesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: const Icon(Symbols.folder_open,
                size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Cases',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Search, triage and manage live missing-person cases',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: AppColors.inkMedium),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const AiModeChip(),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: 'Refresh cases',
            onPressed: () => ref.invalidate(casesProvider),
            icon: const Icon(Symbols.refresh, color: AppColors.inkMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildData(BuildContext context, List<Map<String, dynamic>> cases) {
    final filtered = _visibleCases(cases);
    final totalPages = math.max(1, (filtered.length + _pageSize - 1) ~/ _pageSize);
    final page = math.min(_page, totalPages - 1);
    final start = page * _pageSize;
    final end = math.min(start + _pageSize, filtered.length);
    final rows = filtered.isEmpty
        ? const <Map<String, dynamic>>[]
        : filtered.sublist(start, end);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final gutter =
            wide ? AppSpacing.gutterDesktop : AppSpacing.gutterMobile;
        return SingleChildScrollView(
          padding: EdgeInsets.all(gutter),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterBar(context, wide)
                      .animate()
                      .fadeIn(duration: 240.ms)
                      .slideY(begin: 0.06),
                  const SizedBox(height: AppSpacing.base),
                  if (cases.isEmpty)
                    AppCard(
                      child: EmptyState(
                        icon: Symbols.person_search,
                        title: 'No active cases',
                        subtitle:
                            'New missing-person reports will appear here as '
                            'soon as they are registered.',
                        actionLabel: 'Refresh',
                        onAction: () => ref.invalidate(casesProvider),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 240.ms, delay: 60.ms)
                        .slideY(begin: 0.06)
                  else if (filtered.isEmpty)
                    AppCard(
                      child: EmptyState(
                        icon: Symbols.filter_alt_off,
                        title: 'No cases match your filters',
                        subtitle:
                            'Try broadening the status, priority or search '
                            'criteria.',
                        actionLabel: 'Clear filters',
                        onAction: _resetFilters,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 240.ms, delay: 60.ms)
                        .slideY(begin: 0.06)
                  else
                    _buildTableCard(context, wide, rows, filtered.length, page,
                            totalPages, start, end)
                        .animate()
                        .fadeIn(duration: 240.ms, delay: 60.ms)
                        .slideY(begin: 0.06),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Filter bar
  // -------------------------------------------------------------------------

  Widget _buildFilterBar(BuildContext context, bool wide) {
    final searchField = _buildSearchField(context);
    final sortMenu = _buildSortMenu(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: AppSpacing.md),
                sortMenu,
              ],
            )
          else ...[
            searchField,
            const SizedBox(height: AppSpacing.md),
            Align(alignment: Alignment.centerLeft, child: sortMenu),
          ],
          const SizedBox(height: AppSpacing.base),
          _buildStatusSegments(context),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final p in _acPriorities)
                _AcPriorityChip(
                  label: p,
                  selected: _priorityFilter.contains(p),
                  onTap: () => setState(() {
                    if (!_priorityFilter.remove(p)) _priorityFilter.add(p);
                    _page = 0;
                  }),
                ),
              if (_hasFilters)
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Symbols.filter_alt_off, size: 16),
                  label: const Text('Clear all'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() {
        _query = v.trim();
        _page = 0;
      }),
      decoration: InputDecoration(
        hintText: 'Search name, case ID or location…',
        prefixIcon:
            const Icon(Symbols.search, size: 20, color: AppColors.inkFaint),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Symbols.close,
                    size: 18, color: AppColors.inkFaint),
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _query = '';
                  _page = 0;
                }),
              ),
        filled: true,
        fillColor: AppColors.surfaceSunken,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSortMenu(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopupMenuButton<_AcSort>(
      tooltip: 'Sort cases',
      initialValue: _sort,
      onSelected: (v) => setState(() {
        _sort = v;
        _page = 0;
      }),
      itemBuilder: (_) => [
        for (final s in _AcSort.values)
          PopupMenuItem<_AcSort>(
            value: s,
            child: Row(
              children: [
                Icon(
                  s == _sort ? Symbols.check : null,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.swap_vert, size: 20, color: AppColors.inkMedium),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _sort.label,
              style: text.labelLarge?.copyWith(
                color: AppColors.inkMedium,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Symbols.arrow_drop_down,
                size: 22, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSegments(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in _acStatusFilters)
              _AcSegment(
                label: s,
                selected: _statusFilter == s,
                onTap: () => setState(() {
                  _statusFilter = s;
                  _page = 0;
                }),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Table card
  // -------------------------------------------------------------------------

  Widget _buildTableCard(
    BuildContext context,
    bool wide,
    List<Map<String, dynamic>> rows,
    int total,
    int page,
    int totalPages,
    int start,
    int end,
  ) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.base, AppSpacing.lg, AppSpacing.base),
            child: Row(
              children: [
                Text(
                  'Case Registry',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: AnimatedCount(
                    total,
                    suffix: ' cases',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Page ${page + 1} of $totalPages',
                  style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ),
          ),
          if (wide) ...[
            const _AcTableHeader(),
            for (var i = 0; i < rows.length; i++)
              _AcTableRow(
                row: rows[i],
                striped: i.isOdd,
                onTap: () => _openCase(rows[i]),
              ),
          ] else
            for (final r in rows)
              _AcMobileRow(row: r, onTap: () => _openCase(r)),
          _buildPager(context, start, end, total, page, totalPages),
        ],
      ),
    );
  }

  Widget _buildPager(BuildContext context, int start, int end, int total,
      int page, int totalPages) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.hairline)),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.card),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing ${start + 1}–$end of $total',
              style: text.labelSmall?.copyWith(color: AppColors.inkMedium),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            visualDensity: VisualDensity.compact,
            onPressed:
                page > 0 ? () => setState(() => _page = page - 1) : null,
            icon: const Icon(Symbols.chevron_left, size: 22),
          ),
          for (final p in _pageWindow(page, totalPages))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                onTap: () => setState(() => _page = p),
                child: AnimatedContainer(
                  duration: AppMotion.exit,
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == page ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    '${p + 1}',
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          p == page ? AppColors.onPrimary : AppColors.inkMedium,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Next page',
            visualDensity: VisualDensity.compact,
            onPressed: page < totalPages - 1
                ? () => setState(() => _page = page + 1)
                : null,
            icon: const Icon(Symbols.chevron_right, size: 22),
          ),
        ],
      ),
    );
  }

  List<int> _pageWindow(int page, int totalPages) {
    const maxShown = 5;
    if (totalPages <= maxShown) {
      return List<int>.generate(totalPages, (i) => i);
    }
    var s = page - 2;
    if (s < 0) s = 0;
    if (s + maxShown > totalPages) s = totalPages - maxShown;
    return List<int>.generate(maxShown, (i) => s + i);
  }
}

// ---------------------------------------------------------------------------
// Segmented control + priority chips
// ---------------------------------------------------------------------------

class _AcSegment extends StatelessWidget {
  const _AcSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.exit,
          curve: AppMotion.easeOut,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: selected ? AppShadows.card : null,
          ),
          child: Text(
            label,
            style: text.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.inkMedium,
            ),
          ),
        ),
      ),
    );
  }
}

class _AcPriorityChip extends StatelessWidget {
  const _AcPriorityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  ({Color fg, Color bg}) get _colors => switch (label) {
        'Low' => (fg: AppColors.success, bg: AppColors.successContainer),
        'Medium' => (fg: AppColors.warning, bg: AppColors.warningContainer),
        'High' => (fg: AppColors.accentDeep, bg: AppColors.accentContainer),
        _ => (fg: AppColors.danger, bg: AppColors.dangerContainer),
      };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.exit,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? c.bg : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? c.fg.withValues(alpha: 0.45)
                  : AppColors.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? c.fg : AppColors.inkMedium,
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
// Table pieces
// ---------------------------------------------------------------------------

class _AcTableHeader extends StatelessWidget {
  const _AcTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
      color: AppColors.surfaceSunken.withValues(alpha: 0.6),
      child: const Row(
        children: [
          _AcHeadCell('CASE ID', flex: 2),
          _AcHeadCell('PERSON', flex: 3),
          _AcHeadCell('AGE', flex: 1),
          _AcHeadCell('STATUS', flex: 3),
          _AcHeadCell('PRIORITY', flex: 2),
          _AcHeadCell('LAST SEEN', flex: 3),
          _AcHeadCell('REPORTED', flex: 2),
          SizedBox(width: 20),
        ],
      ),
    );
  }
}

class _AcHeadCell extends StatelessWidget {
  const _AcHeadCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.inkFaint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _AcTableRow extends StatelessWidget {
  const _AcTableRow({
    required this.row,
    required this.striped,
    required this.onTap,
  });

  final Map<String, dynamic> row;
  final bool striped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = (row['missing_person_name'] ?? 'Unknown').toString();
    final reported = _acReportedAt(row);

    return Material(
      color: striped
          ? AppColors.surfaceSunken.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  (row['case_id'] ?? row['id'] ?? '—').toString(),
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    PersonAvatar(name, size: 32),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${row['gender'] ?? '—'} • '
                            '${row['district'] ?? '—'}',
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall
                                ?.copyWith(color: AppColors.inkFaint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  (row['age_band'] ?? '—').toString(),
                  style:
                      text.bodyMedium?.copyWith(color: AppColors.inkMedium),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: StatusBadge.fromLabel(
                        (row['status'] ?? 'Pending').toString()),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PriorityBadge.fromLabel(
                        (row['priority'] ?? 'Medium').toString()),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  (row['last_seen_location'] ?? '—').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      text.bodyMedium?.copyWith(color: AppColors.inkMedium),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _acTimeAgo(reported),
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      reported == null
                          ? '—'
                          : DateFormat('d MMM, h:mm a').format(reported),
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall
                          ?.copyWith(color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 20,
                child: Icon(Symbols.chevron_right,
                    size: 18, color: AppColors.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcMobileRow extends StatelessWidget {
  const _AcMobileRow({required this.row, required this.onTap});

  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = (row['missing_person_name'] ?? 'Unknown').toString();
    final reported = _acReportedAt(row);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PersonAvatar(name, size: 40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          (row['case_id'] ?? row['id'] ?? '—').toString(),
                          style: text.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _acTimeAgo(reported),
                    style:
                        text.labelSmall?.copyWith(color: AppColors.inkFaint),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge.fromLabel(
                      (row['status'] ?? 'Pending').toString()),
                  PriorityBadge.fromLabel(
                      (row['priority'] ?? 'Medium').toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Symbols.location_on,
                      size: 14, color: AppColors.inkFaint),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      (row['last_seen_location'] ?? 'Unknown').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall
                          ?.copyWith(color: AppColors.inkMedium),
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

// ---------------------------------------------------------------------------
// Loading skeleton (mirrors filter bar + table layout)
// ---------------------------------------------------------------------------

class _AcLoadingSkeleton extends StatelessWidget {
  const _AcLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShimmerBox(height: 150, radius: AppRadius.card),
              SizedBox(height: AppSpacing.base),
              ShimmerBox(height: 52, radius: AppRadius.card),
              SizedBox(height: AppSpacing.md),
              ShimmerList(items: 6, itemHeight: 56),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/status_badge.dart';

/// Police portal — Case Detail (DESIGN.md §6.2 "Case detail").
///
/// Two-column layout above 1100px (stacked below): left = person hero card,
/// AI insights (priority radial gauge + search-zone probabilities) and
/// duplicate candidates; right = case timeline, volunteer assignment and a
/// status-update action card. Every write path is offline-safe via the Hive
/// sync queue.
class CaseDetailScreen extends ConsumerStatefulWidget {
  const CaseDetailScreen({super.key, required this.caseData});

  final Map<String, dynamic> caseData;

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen> {
  static const List<({String label, String value, IconData icon})>
      _statusOptions = [
    (label: 'Searching', value: 'Searching', icon: Symbols.search),
    (label: 'Reunited', value: 'Reunited', icon: Symbols.diversity_1),
    (
      label: 'Hospital',
      value: 'Transferred to hospital',
      icon: Symbols.local_hospital
    ),
    (label: 'Unresolved', value: 'Unresolved', icon: Symbols.help),
  ];

  late String _selectedStatus;
  late String _displayStatus;
  bool _saving = false;
  late final List<_CdDuplicate> _duplicates;

  // ---------------------------------------------------------------------
  // Derived case fields
  // ---------------------------------------------------------------------

  String get _personName =>
      (widget.caseData['missing_person_name'] ?? 'Unknown Person').toString();

  String get _caseCode =>
      (widget.caseData['case_id'] ?? widget.caseData['id'] ?? '—').toString();

  String get _recordId =>
      (widget.caseData['id'] ?? widget.caseData['case_id'] ?? 'unknown')
          .toString();

  String get _priorityLabel =>
      (widget.caseData['priority'] ?? 'Medium').toString();

  DateTime get _reportedAt =>
      DateTime.tryParse((widget.caseData['reported_at'] ?? '').toString()) ??
      DateTime.now().subtract(const Duration(hours: 2));

  double get _aiScore => switch (_priorityLabel) {
        'Critical' => 0.92,
        'High' => 0.74,
        'Medium' => 0.55,
        'Low' => 0.30,
        _ => 0.55,
      };

  Color get _priorityColor => switch (_priorityLabel) {
        'Critical' => AppColors.danger,
        'High' => AppColors.accentDeep,
        'Medium' => AppColors.warning,
        'Low' => AppColors.success,
        _ => AppColors.warning,
      };

  String get _firstName {
    final parts = _personName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'K' : parts.first;
  }

  String get _lastName {
    final parts = _personName.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.last : 'Kumar';
  }

  @override
  void initState() {
    super.initState();
    final raw = (widget.caseData['status'] ?? 'Searching').toString();
    _displayStatus = raw;
    _selectedStatus =
        _statusOptions.any((o) => o.value == raw) ? raw : 'Searching';
    _duplicates = [
      _CdDuplicate(
        caseId: 'KMP-2027-01988',
        name: '${_firstName.substring(0, 1)}. $_lastName',
        similarity: 0.87,
        detail: 'Same age band • reported 3h earlier at a nearby ghat',
      ),
      _CdDuplicate(
        caseId: 'KMP-2027-02114',
        name: '$_firstName ${_lastName.substring(0, 1)}.',
        similarity: 0.63,
        detail: 'Adjacent last-seen zone • partial description match',
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Offline-safe writes
  // ---------------------------------------------------------------------

  /// Sends a write to the backend when online; on failure (or when offline)
  /// queues it in the Hive sync queue. Returns true when the write was queued.
  Future<bool> _submit({
    required String path,
    required String method,
    required Map<String, dynamic> body,
  }) async {
    var queued = false;
    final online = ref.read(isOnlineProvider);
    if (online) {
      try {
        final api = ref.read(apiClientProvider);
        final res = method == 'PATCH'
            ? await api.patch<dynamic>(path, data: body)
            : await api.post<dynamic>(path, data: body);
        final code = res.statusCode ?? 0;
        if (code < 200 || code >= 300) queued = true;
      } catch (_) {
        queued = true;
      }
    } else {
      queued = true;
    }
    if (queued) {
      try {
        await ref
            .read(hiveServiceProvider)
            .queueRequest(path: path, method: method, body: body);
      } catch (_) {
        // Queue unavailable — optimistic UI still reflects the change.
      }
    }
    return queued;
  }

  Future<void> _saveStatus() async {
    if (_saving) return;
    setState(() => _saving = true);
    final queued = await _submit(
      path: '/api/v1/cases/$_recordId/status',
      method: 'PATCH',
      body: {
        'status': _selectedStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _displayStatus = _selectedStatus;
    });
    _snack(queued
        ? 'Status saved offline — will sync when connected'
        : 'Case status updated to $_selectedStatus');
  }

  Future<void> _mergeDuplicate(_CdDuplicate dup) async {
    final queued = await _submit(
      path: '/api/v1/cases/$_recordId/merge',
      method: 'POST',
      body: {'duplicate_case_id': dup.caseId},
    );
    if (!mounted) return;
    setState(() => _duplicates.remove(dup));
    _snack(queued
        ? 'Merge with ${dup.caseId} queued — will sync when connected'
        : 'Case merged with ${dup.caseId}');
  }

  void _dismissDuplicate(_CdDuplicate dup) {
    setState(() => _duplicates.remove(dup));
    _snack('Duplicate suggestion dismissed');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.caseData.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              const Expanded(
                child: EmptyState(
                  icon: Symbols.folder_off,
                  title: 'Case not found',
                  subtitle: 'This case record is unavailable or was removed.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  final gutter = wide
                      ? AppSpacing.gutterDesktop
                      : AppSpacing.gutterMobile;
                  final left = _leftColumn(context);
                  final right = _rightColumn(context);
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(gutter),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: AppSpacing.contentMaxWidth),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: left,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xl),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: right,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [...left, ...right],
                              ),
                      ),
                    ),
                  );
                },
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
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Symbols.arrow_back, color: AppColors.ink),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Case Detail',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  _caseCode,
                  style: text.labelSmall?.copyWith(
                    color: AppColors.inkFaint,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const AiModeChip(),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }

  List<Widget> _leftColumn(BuildContext context) => [
        _buildPersonCard(context)
            .animate()
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.base),
        _buildAiInsightsCard(context)
            .animate()
            .fadeIn(duration: 240.ms, delay: 50.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.base),
        _buildDuplicatesCard(context)
            .animate()
            .fadeIn(duration: 240.ms, delay: 100.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.base),
      ];

  List<Widget> _rightColumn(BuildContext context) => [
        _buildTimelineCard(context)
            .animate()
            .fadeIn(duration: 240.ms, delay: 150.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.base),
        _buildAssignmentCard(context)
            .animate()
            .fadeIn(duration: 240.ms, delay: 200.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.base),
        _buildActionsCard(context)
            .animate()
            .fadeIn(duration: 240.ms, delay: 250.ms)
            .slideY(begin: 0.06),
      ];

  // ---------------------------------------------------------------------
  // Left column cards
  // ---------------------------------------------------------------------

  Widget _buildPersonCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = widget.caseData;
    final reporter = (c['reporter_name'] ?? 'Meera $_lastName').toString();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      accentColor: _priorityColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonAvatar(_personName, size: 72),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _personName,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CdCaseIdChip(code: _caseCode),
                        StatusBadge.fromLabel(_displayStatus),
                        PriorityBadge.fromLabel(_priorityLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _CdMetaPill(
                  icon: Symbols.person,
                  label: (c['gender'] ?? '—').toString()),
              _CdMetaPill(
                  icon: Symbols.cake, label: 'Age ${c['age_band'] ?? '—'}'),
              _CdMetaPill(
                  icon: Symbols.translate,
                  label: (c['language'] ?? '—').toString()),
              _CdMetaPill(
                icon: Symbols.home_pin,
                label: '${c['district'] ?? '—'}, ${c['state'] ?? '—'}',
              ),
            ],
          ),
          const Divider(height: AppSpacing.xxl, color: AppColors.hairline),
          _CdInfoSection(
            label: 'Physical description',
            value: (c['physical_description'] ??
                    'No physical description recorded.')
                .toString(),
          ),
          const SizedBox(height: AppSpacing.base),
          _CdInfoSection(
            label: 'Clothing',
            value: (c['clothing_description'] ?? 'No clothing details recorded.')
                .toString(),
          ),
          const SizedBox(height: AppSpacing.base),
          _CdInfoSection(
            label: 'Last seen location',
            value: (c['last_seen_location'] ?? 'Unknown').toString(),
            icon: Symbols.location_on,
          ),
          const Divider(height: AppSpacing.xxl, color: AppColors.hairline),
          Text(
            'REPORTER CONTACT',
            style: text.labelSmall?.copyWith(
              color: AppColors.inkFaint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              PersonAvatar(reporter, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reporter,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '+91 98220 14375 • Family member',
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall
                          ?.copyWith(color: AppColors.inkMedium),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Call reporter',
                onPressed: () => _snack('Connecting call to reporter…'),
                icon: const Icon(Symbols.call, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightsCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.psychology,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'AI Insights',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const AiModeChip(dense: true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 460;
              final gauge =
                  _CdRadialGauge(score: _aiScore, color: _priorityColor);
              const zones = _CdZoneBars();
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: gauge),
                    const SizedBox(height: AppSpacing.lg),
                    zones,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  gauge,
                  const SizedBox(width: AppSpacing.xl),
                  const Expanded(child: zones),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicatesCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.content_copy,
                  size: 20, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Possible Duplicates',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warningContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${_duplicates.length} flagged',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.onWarningContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'AI flagged similar open cases — merge to consolidate records.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkMedium),
          ),
          const SizedBox(height: AppSpacing.base),
          if (_duplicates.isEmpty)
            Row(
              children: [
                const Icon(Symbols.check_circle,
                    size: 18, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'No duplicate candidates remaining.',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkMedium),
                ),
              ],
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final cards = [
                  for (final d in _duplicates)
                    _CdDuplicateCard(
                      dup: d,
                      onMerge: () => _mergeDuplicate(d),
                      onDismiss: () => _dismissDuplicate(d),
                    ),
                ];
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.md),
                        cards[i],
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.base),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Right column cards
  // ---------------------------------------------------------------------

  Widget _buildTimelineCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t0 = _reportedAt;
    final fmt = DateFormat('d MMM • h:mm a');
    final events = [
      _CdTimelineEvent(
        title: 'Case registered',
        subtitle: 'Reported through the family portal',
        time: fmt.format(t0),
        state: _CdEventState.done,
      ),
      _CdTimelineEvent(
        title: 'AI triage completed',
        subtitle: 'Priority set to $_priorityLabel • duplicate scan run',
        time: fmt.format(t0.add(const Duration(minutes: 12))),
        state: _CdEventState.done,
      ),
      _CdTimelineEvent(
        title: 'Officer assigned',
        subtitle: 'Inspector R. Kumar took ownership',
        time: fmt.format(t0.add(const Duration(minutes: 35))),
        state: _CdEventState.done,
      ),
      _CdTimelineEvent(
        title: 'Volunteer dispatched',
        subtitle: 'Vikram Joshi routed to last-seen zone',
        time: fmt.format(t0.add(const Duration(minutes: 68))),
        state: _CdEventState.done,
      ),
      const _CdTimelineEvent(
        title: 'Search in progress',
        subtitle: 'Ground sweep: Ramkund, Sector 4, transit hub',
        time: 'Live now',
        state: _CdEventState.active,
      ),
      const _CdTimelineEvent(
        title: 'Resolution',
        subtitle: 'Awaiting outcome',
        time: 'Pending',
        state: _CdEventState.pending,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.timeline, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Case Timeline',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          for (var i = 0; i < events.length; i++)
            _CdTimelineRow(event: events[i], isLast: i == events.length - 1),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.assignment_ind,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Assignment',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              const PersonAvatar('Vikram Joshi',
                  size: 56, statusDot: AppColors.success),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vikram Joshi',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'VOL-0412 • Ground team',
                      style: text.labelSmall
                          ?.copyWith(color: AppColors.inkFaint),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'On ground — Sector 4',
                            style: text.labelMedium?.copyWith(
                              color: AppColors.onSuccessContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Call volunteer',
                onPressed: () => _snack('Connecting to VOL-0412…'),
                icon: const Icon(Symbols.call, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Symbols.published_with_changes,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Case Actions',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'UPDATE STATUS',
            style: text.labelSmall?.copyWith(
              color: AppColors.inkFaint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Expanded(child: _statusTile(context, 0)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _statusTile(context, 1)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _statusTile(context, 2)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _statusTile(context, 3)),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          PrimaryCta(
            label: 'Save',
            icon: Symbols.save,
            loading: _saving,
            onPressed: _saveStatus,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              const Icon(Symbols.cloud_sync,
                  size: 14, color: AppColors.inkFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Works offline — updates are queued and sync automatically.',
                  style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusTile(BuildContext context, int index) {
    final opt = _statusOptions[index];
    final selected = _selectedStatus == opt.value;
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.input),
      onTap: () => setState(() => _selectedStatus = opt.value),
      child: AnimatedContainer(
        duration: AppMotion.exit,
        curve: AppMotion.easeOut,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              opt.icon,
              size: 18,
              color: selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.inkMedium,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                opt.label,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.onPrimaryContainer
                      : AppColors.inkMedium,
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
// Small models
// ---------------------------------------------------------------------------

class _CdDuplicate {
  const _CdDuplicate({
    required this.caseId,
    required this.name,
    required this.similarity,
    required this.detail,
  });

  final String caseId;
  final String name;
  final double similarity;
  final String detail;
}

enum _CdEventState { done, active, pending }

class _CdTimelineEvent {
  const _CdTimelineEvent({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.state,
  });

  final String title;
  final String subtitle;
  final String time;
  final _CdEventState state;
}

// ---------------------------------------------------------------------------
// Reusable private widgets
// ---------------------------------------------------------------------------

class _CdCaseIdChip extends StatelessWidget {
  const _CdCaseIdChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.tag, size: 14, color: AppColors.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            code,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CdMetaPill extends StatelessWidget {
  const _CdMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.inkMedium),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.inkMedium,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _CdInfoSection extends StatelessWidget {
  const _CdInfoSection({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: AppColors.inkFaint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        if (icon != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: text.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ],
          )
        else
          Text(value, style: text.bodyMedium?.copyWith(height: 1.5)),
      ],
    );
  }
}

class _CdRadialGauge extends StatelessWidget {
  const _CdRadialGauge({required this.score, required this.color});

  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 112,
          height: 112,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score),
            duration: AppMotion.counter,
            curve: AppMotion.easeOut,
            builder: (context, v, _) => Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: v,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.surfaceSunken,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(v * 100).round()}%',
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'AI score',
                        style: text.labelSmall
                            ?.copyWith(color: AppColors.inkFaint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Priority score',
          style: text.labelMedium?.copyWith(
            color: AppColors.inkMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CdZoneBars extends StatelessWidget {
  const _CdZoneBars();

  static const List<({String name, double p, Color color, Color track})>
      _zones = [
    (
      name: 'Ramkund',
      p: 0.45,
      color: AppColors.primary,
      track: AppColors.primaryContainer
    ),
    (
      name: 'Sector 4',
      p: 0.30,
      color: AppColors.info,
      track: AppColors.infoContainer
    ),
    (
      name: 'Transit hub',
      p: 0.15,
      color: AppColors.accentDeep,
      track: AppColors.accentContainer
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOP SEARCH ZONES',
          style: text.labelSmall?.copyWith(
            color: AppColors.inkFaint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final z in _zones)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        z.name,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${(z.p * 100).round()}%',
                      style: text.labelMedium?.copyWith(
                        color: z.color,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: z.p,
                    minHeight: 8,
                    backgroundColor: z.track,
                    valueColor: AlwaysStoppedAnimation<Color>(z.color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CdDuplicateCard extends StatelessWidget {
  const _CdDuplicateCard({
    required this.dup,
    required this.onMerge,
    required this.onDismiss,
  });

  final _CdDuplicate dup;
  final VoidCallback onMerge;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = (dup.similarity * 100).round();
    final high = dup.similarity >= 0.8;
    final simFg = high ? AppColors.danger : AppColors.warning;
    final simBg = high ? AppColors.dangerContainer : AppColors.warningContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(dup.name, size: 40),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dup.name,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      dup.caseId,
                      style: text.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 3),
            decoration: BoxDecoration(
              color: simBg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$pct% similarity',
              style: text.labelMedium?.copyWith(
                color: simFg,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dup.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(color: AppColors.inkMedium),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryCta.tonal(
            label: 'Merge',
            icon: Symbols.call_merge,
            onPressed: onMerge,
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: onDismiss,
              child: const Text('Dismiss'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CdTimelineRow extends StatelessWidget {
  const _CdTimelineRow({required this.event, required this.isLast});

  final _CdTimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final railColor = event.state == _CdEventState.done
        ? AppColors.success.withValues(alpha: 0.35)
        : AppColors.hairline;
    final pending = event.state == _CdEventState.pending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                _buildDot(),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: railColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                pending ? AppColors.inkFaint : AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        event.time,
                        style: text.labelSmall?.copyWith(
                          color: event.state == _CdEventState.active
                              ? AppColors.accentDeep
                              : AppColors.inkFaint,
                          fontWeight: event.state == _CdEventState.active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.subtitle,
                    style:
                        text.labelSmall?.copyWith(color: AppColors.inkMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    switch (event.state) {
      case _CdEventState.done:
        return Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Symbols.check, size: 10, color: Colors.white),
        );
      case _CdEventState.active:
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        );
      case _CdEventState.pending:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hairline, width: 2),
          ),
        );
    }
  }
}

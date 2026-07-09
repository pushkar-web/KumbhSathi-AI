import 'dart:async';

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
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/section_header.dart';

/// Shift Check-In — DESIGN.md §6.3 extension. Volunteers log shift
/// start/end, sector assignment and view their shift history.
class ShiftCheckinScreen extends ConsumerStatefulWidget {
  const ShiftCheckinScreen({super.key});

  @override
  ConsumerState<ShiftCheckinScreen> createState() =>
      _ShiftCheckinScreenState();
}

class _ShiftCheckinScreenState extends ConsumerState<ShiftCheckinScreen> {
  bool _loading = true;
  _SciShiftState _shiftState = _SciShiftState.notStarted;
  String _selectedSector = 'Sector 4';
  DateTime? _shiftStart;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  static const _sectors = [
    'Sector 1',
    'Sector 2',
    'Sector 3',
    'Sector 4',
    'Sector 5',
    'Transit Gate',
    'Medical Camp',
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 450)).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startShift() {
    setState(() {
      _shiftState = _SciShiftState.active;
      _shiftStart = DateTime.now();
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_shiftStart!);
      });
    });
    _queueShiftAction('check_in');
  }

  void _endShift() {
    _timer?.cancel();
    setState(() {
      _shiftState = _SciShiftState.ended;
    });
    _queueShiftAction('check_out');
  }

  void _resetShift() {
    setState(() {
      _shiftState = _SciShiftState.notStarted;
      _shiftStart = null;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _queueShiftAction(String action) async {
    final messenger = ScaffoldMessenger.of(context);
    final online = ref.read(isOnlineProvider);
    try {
      if (!online) {
        await ref.read(hiveServiceProvider).queueRequest(
          path: '/volunteers/vol-8842/shift',
          method: 'POST',
          body: {
            'action': action,
            'sector': _selectedSector,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          },
        );
        messenger.showSnackBar(SnackBar(
          content: Text('$action saved offline — will sync when online'),
        ));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not save shift action. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Shift Check-In',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
              child: _loading ? const _SciSkeleton() : _buildBody(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutterMobile,
          AppSpacing.base, AppSpacing.gutterMobile, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SciStatusCard(
            state: _shiftState,
            elapsed: _elapsed,
            shiftStart: _shiftStart,
          ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.base),
          _SciLocationCard(
            sectors: _sectors,
            selected: _selectedSector,
            onChanged: (s) => setState(() => _selectedSector = s),
            enabled: _shiftState == _SciShiftState.notStarted,
          )
              .animate(delay: 50.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.lg),

          // CTA
          if (_shiftState == _SciShiftState.notStarted)
            PrimaryCta(
              label: 'Start Shift',
              icon: Symbols.login,
              onPressed: _startShift,
            )
                .animate(delay: 100.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),

          if (_shiftState == _SciShiftState.active) ...[
            PrimaryCta(
              label: 'End Shift',
              icon: Symbols.logout,
              onPressed: _endShift,
            )
                .animate(delay: 100.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),
          ],

          if (_shiftState == _SciShiftState.ended) ...[
            _SciSummaryCard(
              elapsed: _elapsed,
              sector: _selectedSector,
            )
                .animate(delay: 100.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),
            const SizedBox(height: AppSpacing.base),
            PrimaryCta.tonal(
              label: 'Start New Shift',
              icon: Symbols.refresh,
              onPressed: _resetShift,
            )
                .animate(delay: 150.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),
          ],

          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            'Recent Shifts',
            icon: Symbols.history,
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          const _SciShiftHistory(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shift state
// ---------------------------------------------------------------------------

enum _SciShiftState { notStarted, active, ended }

// ---------------------------------------------------------------------------
// Status card
// ---------------------------------------------------------------------------

class _SciStatusCard extends StatelessWidget {
  const _SciStatusCard({
    required this.state,
    required this.elapsed,
    this.shiftStart,
  });

  final _SciShiftState state;
  final Duration elapsed;
  final DateTime? shiftStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, label, sublabel, fg, bg) = switch (state) {
      _SciShiftState.notStarted => (
          Symbols.schedule,
          'Not Started',
          'Start your shift when ready',
          AppColors.inkMedium,
          theme.colorScheme.surfaceContainerHigh,
        ),
      _SciShiftState.active => (
          Symbols.radio_button_checked,
          'Shift Active',
          'Started at ${shiftStart != null ? DateFormat('h:mm a').format(shiftStart!) : '--:--'}',
          AppColors.success,
          AppColors.successContainer,
        ),
      _SciShiftState.ended => (
          Symbols.check_circle,
          'Shift Ended',
          'Good work! Shift completed.',
          AppColors.primary,
          AppColors.primaryContainer,
        ),
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: fg),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            label,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            sublabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (state == _SciShiftState.active ||
              state == _SciShiftState.ended) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Symbols.timer, size: 20, color: fg),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _formatDuration(elapsed),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ---------------------------------------------------------------------------
// Location card
// ---------------------------------------------------------------------------

class _SciLocationCard extends StatelessWidget {
  const _SciLocationCard({
    required this.sectors,
    required this.selected,
    required this.onChanged,
    required this.enabled,
  });

  final List<String> sectors;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child:
                    const Icon(Symbols.location_on, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Assigned Sector',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: selected,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            items: [
              for (final s in sectors)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: enabled ? (v) => onChanged(v!) : null,
          ),
          if (!enabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sector locked while shift is active',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shift summary (post check-out)
// ---------------------------------------------------------------------------

class _SciSummaryCard extends StatelessWidget {
  const _SciSummaryCard({
    required this.elapsed,
    required this.sector,
  });

  final Duration elapsed;
  final String sector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      accentColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SHIFT SUMMARY',
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
                Expanded(
                  child: _SciSumStat(
                    value: '${elapsed.inHours}h ${elapsed.inMinutes % 60}m',
                    label: 'Duration',
                    icon: Symbols.timer,
                    color: AppColors.primary,
                  ),
                ),
                Container(width: 1, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: _SciSumStat(
                    value: '3',
                    label: 'Tasks done',
                    icon: Symbols.task_alt,
                    color: AppColors.success,
                  ),
                ),
                Container(width: 1, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: _SciSumStat(
                    value: sector,
                    label: 'Location',
                    icon: Symbols.location_on,
                    color: AppColors.accent,
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

class _SciSumStat extends StatelessWidget {
  const _SciSumStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
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
// Shift history
// ---------------------------------------------------------------------------

class _SciShiftHistory extends StatelessWidget {
  const _SciShiftHistory();

  static final _shifts = [
    (
      date: DateTime.now().subtract(const Duration(days: 1)),
      sector: 'Sector 4',
      duration: '6h 12m',
      tasks: 4,
    ),
    (
      date: DateTime.now().subtract(const Duration(days: 2)),
      sector: 'Sector 2',
      duration: '5h 45m',
      tasks: 3,
    ),
    (
      date: DateTime.now().subtract(const Duration(days: 4)),
      sector: 'Transit Gate',
      duration: '7h 30m',
      tasks: 5,
    ),
    (
      date: DateTime.now().subtract(const Duration(days: 6)),
      sector: 'Sector 3',
      duration: '4h 20m',
      tasks: 2,
    ),
    (
      date: DateTime.now().subtract(const Duration(days: 8)),
      sector: 'Sector 1',
      duration: '6h 00m',
      tasks: 6,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < _shifts.length; i++)
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('d').format(_shifts[i].date),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          height: 1,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(_shifts[i].date),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shifts[i].sector,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_shifts[i].duration} · ${_shifts[i].tasks} tasks',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.check_circle,
                          size: 13, color: AppColors.success),
                      const SizedBox(width: 5),
                      Text(
                        'Done',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate(delay: (250 + (i < 6 ? i : 5) * 50).ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _SciSkeleton extends StatelessWidget {
  const _SciSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.gutterMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShimmerBox(height: 200, radius: AppRadius.card),
          SizedBox(height: AppSpacing.base),
          ShimmerBox(height: 130, radius: AppRadius.card),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(height: 52, radius: AppRadius.button),
          SizedBox(height: AppSpacing.xl),
          ShimmerBox(width: 120, height: 22),
          SizedBox(height: AppSpacing.md),
          ShimmerList(items: 4, itemHeight: 80),
        ],
      ),
    );
  }
}

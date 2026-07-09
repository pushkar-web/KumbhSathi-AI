import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/section_header.dart';

/// Volunteer Profile — performance stats, badges, training, shift summary
/// and notification preferences. Read-only profile data with settings toggles.
class VolunteerProfileScreen extends ConsumerStatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  ConsumerState<VolunteerProfileScreen> createState() =>
      _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState
    extends ConsumerState<VolunteerProfileScreen> {
  bool _loading = true;
  bool _notifAssignments = true;
  bool _notifSos = true;
  bool _notifSystem = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 450)).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
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
              child: _loading
                  ? const _VpSkeleton()
                  : _buildBody(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final user = ref.watch(authStateProvider).user;
    final name = (user == null || user.fullName.trim().isEmpty)
        ? 'Rajesh Patel'
        : user.fullName;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero profile card
          _VpHeroCard(name: name)
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),

          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutterMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.base),

                // Performance KPIs
                const _VpKpiRow()
                    .animate(delay: 50.ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: 0.06),

                // Badges
                SectionHeader(
                  'Badges & Achievements',
                  icon: Symbols.military_tech,
                )
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: 0.06),
                const _VpBadgesRow()
                    .animate(delay: 150.ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: 0.06),

                // Shift summary
                SectionHeader(
                  'Shift Summary',
                  icon: Symbols.calendar_month,
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: 0.06),
                const _VpShiftSummaryCard()
                    .animate(delay: 250.ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: 0.06),

                // Skills & Training
                SectionHeader(
                  'Skills & Training',
                  icon: Symbols.school,
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: 0.06),
                const _VpTrainingList(),

                // Notification preferences
                SectionHeader(
                  'Notification Preferences',
                  icon: Symbols.notifications,
                ),
                AppCard(
                  child: Column(
                    children: [
                      _VpSettingToggle(
                        icon: Symbols.assignment,
                        label: 'Assignment Updates',
                        subtitle: 'New cases and status changes',
                        value: _notifAssignments,
                        onChanged: (v) =>
                            setState(() => _notifAssignments = v),
                      ),
                      Divider(
                          height: 1, color: theme.colorScheme.outlineVariant),
                      _VpSettingToggle(
                        icon: Symbols.emergency,
                        label: 'SOS Alerts',
                        subtitle: 'Emergency alerts in your sector',
                        value: _notifSos,
                        onChanged: (v) =>
                            setState(() => _notifSos = v),
                      ),
                      Divider(
                          height: 1, color: theme.colorScheme.outlineVariant),
                      _VpSettingToggle(
                        icon: Symbols.settings,
                        label: 'System Updates',
                        subtitle: 'App updates and maintenance notices',
                        value: _notifSystem,
                        onChanged: (v) =>
                            setState(() => _notifSystem = v),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Hero card
// ---------------------------------------------------------------------------

class _VpHeroCard extends StatelessWidget {
  const _VpHeroCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(AppRadius.hero)),
      ),
      child: Column(
        children: [
          PersonAvatar(name, size: 72, statusDot: AppColors.success),
          const SizedBox(height: AppSpacing.md),
          Text(
            name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Volunteer · VOL-8842',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              _VpHeroChip(icon: Symbols.verified, label: 'Verified'),
              _VpHeroChip(icon: Symbols.location_on, label: 'Sector 4'),
              _VpHeroChip(icon: Symbols.schedule, label: 'Since Jan 2027'),
            ],
          ),
        ],
      ),
    );
  }
}

class _VpHeroChip extends StatelessWidget {
  const _VpHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI row
// ---------------------------------------------------------------------------

class _VpKpiRow extends StatelessWidget {
  const _VpKpiRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'Cases Resolved',
                value: 12,
                icon: Symbols.check_circle,
                color: AppColors.success,
                containerColor: AppColors.successContainer,
                deltaLabel: '+3 this week',
                deltaPositive: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: KpiCard(
                label: 'Active Hours',
                value: 148,
                suffix: 'h',
                icon: Symbols.timer,
                color: AppColors.primary,
                containerColor: AppColors.primaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'Tasks Done',
                value: 47,
                icon: Symbols.task_alt,
                color: AppColors.info,
                containerColor: AppColors.infoContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: KpiCard(
                label: 'Avg Response',
                value: 8.5,
                suffix: 'm',
                decimals: 1,
                icon: Symbols.speed,
                color: AppColors.accent,
                containerColor: AppColors.accentContainer,
                deltaLabel: '-2m faster',
                deltaPositive: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

class _VpBadge {
  const _VpBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.container,
    required this.earned,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color container;
  final bool earned;
}

class _VpBadgesRow extends StatelessWidget {
  const _VpBadgesRow();

  static const _badges = [
    _VpBadge(
      icon: Symbols.favorite,
      label: 'First\nReunion',
      color: AppColors.danger,
      container: AppColors.dangerContainer,
      earned: true,
    ),
    _VpBadge(
      icon: Symbols.dark_mode,
      label: 'Night\nOwl',
      color: AppColors.primary,
      container: AppColors.primaryContainer,
      earned: true,
    ),
    _VpBadge(
      icon: Symbols.timer,
      label: '100\nHours',
      color: AppColors.success,
      container: AppColors.successContainer,
      earned: true,
    ),
    _VpBadge(
      icon: Symbols.star,
      label: 'Star\nVolunteer',
      color: AppColors.accent,
      container: AppColors.accentContainer,
      earned: true,
    ),
    _VpBadge(
      icon: Symbols.speed,
      label: 'Quick\nResponder',
      color: AppColors.info,
      container: AppColors.infoContainer,
      earned: false,
    ),
    _VpBadge(
      icon: Symbols.workspace_premium,
      label: '500\nHours',
      color: AppColors.hospital,
      container: AppColors.hospitalContainer,
      earned: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _badges.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) {
          final badge = _badges[i];
          return AnimatedOpacity(
            duration: AppMotion.enter,
            opacity: badge.earned ? 1.0 : 0.45,
            child: SizedBox(
              width: 80,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: badge.container,
                      shape: BoxShape.circle,
                      border: badge.earned
                          ? Border.all(color: badge.color, width: 2)
                          : null,
                    ),
                    child: Icon(badge.icon, size: 26, color: badge.color),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    badge.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: badge.earned
                          ? theme.colorScheme.onSurface
                          : AppColors.inkFaint,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shift summary
// ---------------------------------------------------------------------------

class _VpShiftSummaryCard extends StatelessWidget {
  const _VpShiftSummaryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _VpSumCol(
                value: '24',
                label: 'Total\nShifts',
                icon: Symbols.calendar_month,
                color: AppColors.primary,
              ),
            ),
            Container(width: 1, color: theme.colorScheme.outlineVariant),
            Expanded(
              child: _VpSumCol(
                value: '6.2h',
                label: 'Avg\nDuration',
                icon: Symbols.timer,
                color: AppColors.success,
              ),
            ),
            Container(width: 1, color: theme.colorScheme.outlineVariant),
            Expanded(
              child: _VpSumCol(
                value: 'Sec 4',
                label: 'Most\nActive',
                icon: Symbols.location_on,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VpSumCol extends StatelessWidget {
  const _VpSumCol({
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
// Training list
// ---------------------------------------------------------------------------

class _VpTraining {
  const _VpTraining({
    required this.title,
    required this.date,
    required this.completed,
  });

  final String title;
  final String date;
  final bool completed;
}

class _VpTrainingList extends StatelessWidget {
  const _VpTrainingList();

  static const _items = [
    _VpTraining(
      title: 'Crowd Management & Safety',
      date: 'Completed Jan 5, 2027',
      completed: true,
    ),
    _VpTraining(
      title: 'First Aid & Emergency Response',
      date: 'Completed Jan 8, 2027',
      completed: true,
    ),
    _VpTraining(
      title: 'Face Recognition System',
      date: 'Completed Jan 10, 2027',
      completed: true,
    ),
    _VpTraining(
      title: 'Advanced Search Protocols',
      date: 'In progress',
      completed: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++)
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _items[i].completed
                        ? AppColors.successContainer
                        : AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Icon(
                    _items[i].completed
                        ? Symbols.check_circle
                        : Symbols.pending,
                    size: 20,
                    color: _items[i].completed
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _items[i].title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _items[i].completed
                              ? AppColors.success
                              : AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate(delay: (350 + (i < 4 ? i : 3) * 50).ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settings toggle
// ---------------------------------------------------------------------------

class _VpSettingToggle extends StatelessWidget {
  const _VpSettingToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _VpSkeleton extends StatelessWidget {
  const _VpSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShimmerBox(height: 220),
          Padding(
            padding: EdgeInsets.all(AppSpacing.gutterMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AppSpacing.base),
                Row(
                  children: [
                    Expanded(
                        child: ShimmerBox(height: 132, radius: AppRadius.card)),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: ShimmerBox(height: 132, radius: AppRadius.card)),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                        child: ShimmerBox(height: 132, radius: AppRadius.card)),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: ShimmerBox(height: 132, radius: AppRadius.card)),
                  ],
                ),
                SizedBox(height: AppSpacing.xl),
                ShimmerBox(width: 200, height: 22),
                SizedBox(height: AppSpacing.md),
                ShimmerBox(height: 110),
                SizedBox(height: AppSpacing.xl),
                ShimmerBox(width: 160, height: 22),
                SizedBox(height: AppSpacing.md),
                ShimmerBox(height: 100, radius: AppRadius.card),
                SizedBox(height: AppSpacing.xl),
                ShimmerList(items: 4, itemHeight: 72),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

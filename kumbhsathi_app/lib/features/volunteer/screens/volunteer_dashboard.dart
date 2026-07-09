import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import 'found_person_face_scan.dart';
import 'shift_checkin_screen.dart';
import 'sos_emergency_screen.dart';
import 'upload_observation_screen.dart';

/// Volunteer Dashboard — DESIGN.md §6.3. Rebuilt to be a clean command center:
/// hero header, availability toggle, KPIs, quick-action grid, today's briefing,
/// sector map preview, offline readiness, and notifications preview.
/// Assignment content has been moved to the dedicated Assignments tab.
class VolunteerDashboardScreen extends ConsumerWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _VolDashHero()
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
                          const _VolDashAvailabilityCard()
                              .animate(delay: 50.ms)
                              .fadeIn(duration: 240.ms)
                              .slideY(begin: 0.06),
                          const SizedBox(height: AppSpacing.base),
                          const _VolDashKpiRow()
                              .animate(delay: 100.ms)
                              .fadeIn(duration: 240.ms)
                              .slideY(begin: 0.06),

                          // Quick Actions
                          SectionHeader(
                            'Quick Actions',
                            icon: Symbols.bolt,
                          )
                              .animate(delay: 150.ms)
                              .fadeIn(duration: 240.ms)
                              .slideY(begin: 0.06),
                          const _VolDashQuickActions()
                              .animate(delay: 200.ms)
                              .fadeIn(duration: 240.ms)
                              .slideY(begin: 0.06),

                          // Today's Briefing
                          SectionHeader(
                            'Today\'s Briefing',
                            icon: Symbols.description,
                          )
                              .animate(delay: 250.ms)
                              .fadeIn(duration: 240.ms)
                              .slideY(begin: 0.06),
                          const _VolDashBriefingCard()
                              .animate(delay: 300.ms)
                              .fadeIn(duration: 240.ms)
                              .slideY(begin: 0.06),

                          // Sector Map Preview
                          const _VolDashMapPreview()
                              .animate(delay: 350.ms)
                              .fadeIn(duration: 240.ms)
                              .slideY(begin: 0.06),

                          // Offline Readiness
                          SectionHeader(
                            'Offline Readiness',
                            icon: Symbols.cloud_off,
                          ),
                          const _VolDashOfflineCard(),

                          // Notifications
                          SectionHeader(
                            'Recent Notifications',
                            icon: Symbols.notifications,
                            actionLabel: 'View all',
                            onAction: () {},
                          ),
                          const _VolDashNotifications(),
                        ],
                      ),
                    ),
                  ],
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
// Hero header
// ---------------------------------------------------------------------------

class _VolDashHero extends ConsumerWidget {
  const _VolDashHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).user;
    final name = (user == null || user.fullName.trim().isEmpty)
        ? 'Rajesh Patel'
        : user.fullName;
    final date = DateFormat('EEEE, d MMMM').format(DateTime.now());

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PersonAvatar(name, size: 56, statusDot: AppColors.success),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AiModeChip(dense: true),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _VolDashHeroChip(icon: Symbols.badge, label: 'VOL-8842'),
              _VolDashHeroChip(
                  icon: Symbols.verified, label: 'Verified volunteer'),
            ],
          ),
        ],
      ),
    );
  }
}

class _VolDashHeroChip extends StatelessWidget {
  const _VolDashHeroChip({required this.icon, required this.label});

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
// Availability
// ---------------------------------------------------------------------------

class _VolDashAvailabilityCard extends ConsumerWidget {
  const _VolDashAvailabilityCard();

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final online = ref.read(isOnlineProvider);
    try {
      await ref
          .read(volunteerAvailabilityProvider.notifier)
          .updateAvailability('vol-8842', value);
      if (!online) {
        await ref.read(hiveServiceProvider).queueRequest(
          path: '/volunteers/vol-8842/availability',
          method: 'PATCH',
          body: {'is_available': value},
        );
        messenger.showSnackBar(const SnackBar(
          content: Text('Saved offline — availability will sync when online'),
        ));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not update availability. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final available = ref.watch(volunteerAvailabilityProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Availability',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: available,
                onChanged: (v) => _toggle(context, ref, v),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedContainer(
            duration: AppMotion.enter,
            curve: AppMotion.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: available
                  ? AppColors.successContainer
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Row(
              children: [
                Icon(
                  available ? Symbols.check_circle : Symbols.pause_circle,
                  size: 22,
                  color: available
                      ? AppColors.success
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        available
                            ? 'Active & available for search'
                            : 'Off duty',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: available
                              ? AppColors.onSuccessContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        available
                            ? 'Ready for immediate dispatch in Sector 4'
                            : 'You will not receive new assignments',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: available
                              ? AppColors.success
                              : theme.colorScheme.onSurfaceVariant,
                        ),
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
// KPI row
// ---------------------------------------------------------------------------

class _VolDashKpiRow extends ConsumerWidget {
  const _VolDashKpiRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(dashboardKpiProvider);

    return kpiAsync.when(
      loading: () => const Row(
        children: [
          Expanded(child: ShimmerBox(height: 132, radius: AppRadius.card)),
          SizedBox(width: AppSpacing.md),
          Expanded(child: ShimmerBox(height: 132, radius: AppRadius.card)),
          SizedBox(width: AppSpacing.md),
          Expanded(child: ShimmerBox(height: 132, radius: AppRadius.card)),
        ],
      ),
      error: (error, stackTrace) => AppCard(
        child: EmptyState(
          icon: Symbols.signal_disconnected,
          title: 'Stats unavailable',
          subtitle: 'We could not load your volunteer stats.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(dashboardKpiProvider),
        ),
      ),
      data: (_) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: KpiCard(
              label: 'Assigned',
              value: 1,
              icon: Symbols.assignment_ind,
              color: AppColors.primary,
              containerColor: AppColors.primaryContainer,
              onTap: () => ref.read(portalTabProvider.notifier).state = 1,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: KpiCard(
              label: 'Completed',
              value: 12,
              icon: Symbols.task_alt,
              color: AppColors.success,
              containerColor: AppColors.successContainer,
              sparkline: const [2, 4, 3, 6, 5, 8, 7, 10, 9, 12],
              onTap: () => ref.read(portalTabProvider.notifier).state = 2,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: KpiCard(
              label: 'Hours',
              value: 32,
              suffix: 'h',
              icon: Symbols.timer,
              color: AppColors.accentDeep,
              containerColor: AppColors.accentContainer,
              sparkline: const [4, 6, 5, 7, 6, 8, 5, 6, 7, 8],
              onTap: () => ref.read(portalTabProvider.notifier).state = 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions grid
// ---------------------------------------------------------------------------

class _VolDashQuickActions extends StatelessWidget {
  const _VolDashQuickActions();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.8,
      children: [
        _VolDashActionTile(
          icon: Symbols.add_a_photo,
          label: 'Report\nObservation',
          color: AppColors.info,
          container: AppColors.infoContainer,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UploadObservationScreen()),
          ),
        ),
        _VolDashActionTile(
          icon: Symbols.familiar_face_and_zone,
          label: 'Face\nScan',
          color: AppColors.primary,
          container: AppColors.primaryContainer,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const FoundPersonFaceScanScreen()),
          ),
        ),
        _VolDashActionTile(
          icon: Symbols.login,
          label: 'Shift\nCheck-In',
          color: AppColors.success,
          container: AppColors.successContainer,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ShiftCheckinScreen()),
          ),
        ),
        _VolDashActionTile(
          icon: Symbols.emergency,
          label: 'SOS\nEmergency',
          color: AppColors.danger,
          container: AppColors.dangerContainer,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SosEmergencyScreen()),
          ),
        ),
      ],
    );
  }
}

class _VolDashActionTile extends StatelessWidget {
  const _VolDashActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.container,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color container;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: container,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          Icon(Symbols.chevron_right,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's briefing
// ---------------------------------------------------------------------------

class _VolDashBriefingCard extends StatelessWidget {
  const _VolDashBriefingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: const Icon(Symbols.description,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Daily Briefing',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                DateFormat('d MMM').format(DateTime.now()),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          // Briefing items
          _VolDashBriefRow(
            icon: Symbols.location_on,
            label: 'Sector',
            value: 'Sector 4 — Ghat Area',
            color: AppColors.accent,
          ),
          const SizedBox(height: AppSpacing.md),
          _VolDashBriefRow(
            icon: Symbols.schedule,
            label: 'Shift',
            value: '06:00 AM — 02:00 PM',
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          _VolDashBriefRow(
            icon: Symbols.thermostat,
            label: 'Weather',
            value: '34°C Partly Cloudy · Stay hydrated',
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.md),

          // Crowd density bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.groups,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Crowd Density',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'High',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: 0.75,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.warning),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VolDashBriefRow extends StatelessWidget {
  const _VolDashBriefRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label  ',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sector map preview
// ---------------------------------------------------------------------------

class _VolDashMapPreview extends ConsumerWidget {
  const _VolDashMapPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Sector Overview',
          icon: Symbols.map,
          actionLabel: 'Full map',
          onAction: () => ref.read(portalTabProvider.notifier).state = 3,
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Map placeholder with sector markers
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.card)),
                ),
                child: Stack(
                  children: [
                    // Grid overlay to simulate map
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MapGridPainter(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    // Sector zones
                    Positioned(
                      left: 30,
                      top: 30,
                      child: _VolDashMapDot(
                          label: 'S1', color: AppColors.success),
                    ),
                    Positioned(
                      left: 100,
                      top: 50,
                      child: _VolDashMapDot(
                          label: 'S2', color: AppColors.success),
                    ),
                    Positioned(
                      right: 80,
                      top: 25,
                      child: _VolDashMapDot(
                          label: 'S3', color: AppColors.warning),
                    ),
                    Positioned(
                      right: 40,
                      bottom: 40,
                      child: _VolDashMapDot(
                          label: 'S4',
                          color: AppColors.accent,
                          active: true),
                    ),
                    Positioned(
                      left: 60,
                      bottom: 30,
                      child: _VolDashMapDot(
                          label: 'S5', color: AppColors.success),
                    ),
                    // You-are-here pin
                    Positioned(
                      right: 55,
                      bottom: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.chip),
                            ),
                            child: Text(
                              'YOU',
                              style:
                                  theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom info bar
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Symbols.my_location,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Sector 4 — Ghat Area',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentContainer,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '3 active cases',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accentDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VolDashMapDot extends StatelessWidget {
  const _VolDashMapDot({
    required this.label,
    required this.color,
    this.active = false,
  });

  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 38 : 32,
      height: active ? 38 : 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.25 : 0.15),
        shape: BoxShape.circle,
        border: active
            ? Border.all(color: color, width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  _MapGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const step = 30.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) =>
      color != oldDelegate.color;
}

// ---------------------------------------------------------------------------
// Offline readiness
// ---------------------------------------------------------------------------

class _VolDashOfflineCard extends ConsumerWidget {
  const _VolDashOfflineCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final online = ref.watch(isOnlineProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: online
                      ? AppColors.successContainer
                      : AppColors.warningContainer,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(
                  online ? Symbols.cloud_done : Symbols.cloud_off,
                  size: 20,
                  color: online ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      online ? 'Connected' : 'Offline Mode',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      online
                          ? 'All features available'
                          : 'On-device AI active',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Status indicators
          _VolDashOfflineRow(
            label: 'Face Recognition Model',
            status: 'Downloaded',
            isReady: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _VolDashOfflineRow(
            label: 'AI Model (Gemma 3n)',
            status: online ? 'Cloud active' : 'On-device',
            isReady: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _VolDashOfflineRow(
            label: 'Sync Queue',
            status: '0 pending',
            isReady: true,
          ),
        ],
      ),
    );
  }
}

class _VolDashOfflineRow extends StatelessWidget {
  const _VolDashOfflineRow({
    required this.label,
    required this.status,
    required this.isReady,
  });

  final String label;
  final String status;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          isReady ? Symbols.check_circle : Symbols.error,
          size: 14,
          color: isReady ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          status,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isReady ? AppColors.success : AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications preview
// ---------------------------------------------------------------------------

class _VolDashNotification {
  const _VolDashNotification({
    required this.icon,
    required this.color,
    required this.container,
    required this.title,
    required this.caption,
    required this.minutesAgo,
  });

  final IconData icon;
  final Color color;
  final Color container;
  final String title;
  final String caption;
  final int minutesAgo;
}

class _VolDashNotifications extends StatelessWidget {
  const _VolDashNotifications();

  static const _items = [
    _VolDashNotification(
      icon: Symbols.assignment_ind,
      color: AppColors.accent,
      container: AppColors.accentContainer,
      title: 'New assignment received',
      caption: 'Case KMP-2027-01042 · Ramesh Kumar',
      minutesAgo: 15,
    ),
    _VolDashNotification(
      icon: Symbols.groups,
      color: AppColors.warning,
      container: AppColors.warningContainer,
      title: 'High crowd density alert',
      caption: 'Sector 4 Ghat area — exercise caution',
      minutesAgo: 45,
    ),
    _VolDashNotification(
      icon: Symbols.check_circle,
      color: AppColors.success,
      container: AppColors.successContainer,
      title: 'Shift confirmed for tomorrow',
      caption: '06:00 AM — 02:00 PM · Sector 4',
      minutesAgo: 120,
    ),
  ];

  String _relative(int minutes) {
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';
    final days = hours ~/ 24;
    return '${days}d ago';
  }

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
                    color: _items[i].container,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child:
                      Icon(_items[i].icon, size: 20, color: _items[i].color),
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
                        _items[i].caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _relative(_items[i].minutesAgo),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ),
          )
              .animate(delay: (i * 50).ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
      ],
    );
  }
}

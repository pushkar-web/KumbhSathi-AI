import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import 'aadhaar_scanner_screen.dart';
import 'ai_interview_screen.dart';
import 'register_missing_person_screen.dart';
import 'voice_recording_screen.dart';

/// Family portal home — Design System v2 "Sanctum" (DESIGN.md §6.1).
/// Hero gradient header, overlapping quick actions, live case cards and a
/// notifications preview. Offline-first, shimmer loading, staggered entrance.
class FamilyDashboardScreen extends ConsumerWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullName =
        ref.watch(authStateProvider.select((s) => s.user?.fullName));
    final firstName = _famDashFirstName(fullName);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FamDashHero(
                      firstName: firstName,
                      onBellTap: () =>
                          ref.read(portalTabProvider.notifier).state = 2,
                    )
                        .animate()
                        .fadeIn(duration: 240.ms)
                        .slideY(begin: -0.04, curve: Curves.easeOutCubic),
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.gutterMobile),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _FamDashQuickActions()
                                .animate(delay: 60.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06,
                                    curve: Curves.easeOutCubic),
                            SectionHeader(
                              'My Active Cases',
                              icon: Symbols.folder_open,
                              actionLabel: 'Track all',
                              onAction: () => ref
                                  .read(portalTabProvider.notifier)
                                  .state = 1,
                            )
                                .animate(delay: 120.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06,
                                    curve: Curves.easeOutCubic),
                            const _FamDashCasesSection(),
                            SectionHeader(
                              'Recent Notifications',
                              icon: Symbols.campaign,
                              actionLabel: 'View all',
                              onAction: () => ref
                                  .read(portalTabProvider.notifier)
                                  .state = 2,
                            )
                                .animate(delay: 180.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06,
                                    curve: Curves.easeOutCubic),
                            const _FamDashNotifPreview()
                                .animate(delay: 240.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06,
                                    curve: Curves.easeOutCubic),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ),
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

String _famDashFirstName(String? fullName) {
  final trimmed = (fullName ?? '').trim();
  if (trimmed.isEmpty) return 'Sathi';
  return trimmed.split(RegExp(r'\s+')).first;
}

String _famDashElapsed(String? iso) {
  final t = DateTime.tryParse(iso ?? '');
  if (t == null) return '—';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m ago';
  return '${d.inDays}d ago';
}

Color _famDashStatusColor(String status) => switch (status) {
      'Pending' => AppColors.warning,
      'Searching' => AppColors.accent,
      'Reunited' => AppColors.success,
      'Transferred to hospital' => AppColors.hospital,
      'Unresolved' => AppColors.danger,
      _ => AppColors.info,
    };

double _famDashProgress(String status) => switch (status) {
      'Pending' => 0.22,
      'Searching' => 0.55,
      'Transferred to hospital' => 0.78,
      'Unresolved' => 0.9,
      'Reunited' => 1.0,
      _ => 0.3,
    };

Color _famDashPriorityColor(String priority) => switch (priority) {
      'Low' => AppColors.success,
      'Medium' => AppColors.warning,
      'High' => AppColors.accent,
      'Critical' => AppColors.danger,
      _ => AppColors.info,
    };

// ============================================================
// Hero header
// ============================================================
class _FamDashHero extends StatelessWidget {
  const _FamDashHero({required this.firstName, required this.onBellTap});

  final String firstName;
  final VoidCallback onBellTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dateLabel =
        DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.hero),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -46,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl + 24, // extra room for the overlapping block
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Namaste, $firstName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        dateLabel,
                        style: text.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const AiModeChip(dense: true),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _FamDashBell(onTap: onBellTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FamDashBell extends StatelessWidget {
  const _FamDashBell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.white.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: const Icon(
                Symbols.notifications,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        Positioned(
          top: -2,
          right: -2,
          child: IgnorePointer(
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '3',
                style: text.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Overlapping quick actions
// ============================================================
class _FamDashQuickActions extends ConsumerWidget {
  const _FamDashQuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      raised: true,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryCta(
            label: 'Report Missing Person',
            icon: Symbols.person_add,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RegisterMissingPersonScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _FamDashMiniAction(
                  icon: Symbols.location_on,
                  label: 'Track',
                  bg: AppColors.primaryContainer,
                  fg: AppColors.onPrimaryContainer,
                  onTap: () =>
                      ref.read(portalTabProvider.notifier).state = 1,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _FamDashMiniAction(
                  icon: Symbols.upload_file,
                  label: 'Upload Info',
                  bg: AppColors.accentContainer,
                  fg: AppColors.onAccentContainer,
                  onTap: () => _showUploadOptions(context),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _FamDashMiniAction(
                  icon: Symbols.support_agent,
                  label: 'Help',
                  bg: AppColors.successContainer,
                  fg: AppColors.onSuccessContainer,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AiInterviewScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FamDashSheetTile(
              icon: Symbols.mic,
              title: 'Voice Recording',
              subtitle: 'Describe the person in your own language',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const VoiceRecordingScreen(),
                  ),
                );
              },
            ),
            _FamDashSheetTile(
              icon: Symbols.id_card,
              title: 'Aadhaar Scanner',
              subtitle: 'Verify identity offline in seconds',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AadhaarScannerScreen(),
                  ),
                );
              },
            ),
            _FamDashSheetTile(
              icon: Symbols.smart_toy,
              title: 'AI Guided Interview',
              subtitle: 'Answer simple questions, AI fills the report',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AiInterviewScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _FamDashSheetTile extends StatelessWidget {
  const _FamDashSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Icon(icon, color: scheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _FamDashMiniAction extends StatelessWidget {
  const _FamDashMiniAction({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md, horizontal: AppSpacing.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Active cases (casesProvider)
// ============================================================
class _FamDashCasesSection extends ConsumerWidget {
  const _FamDashCasesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(casesProvider);

    return cases.when(
      loading: () => const ShimmerList(items: 3, itemHeight: 116),
      error: (_, __) => EmptyState(
        icon: Symbols.cloud_off,
        title: 'Could not load your cases',
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(casesProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Symbols.folder_open,
            title: 'No active cases',
            subtitle:
                'When you report a missing person, live updates appear here.',
            actionLabel: 'Report Missing Person',
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RegisterMissingPersonScreen(),
                ),
              );
            },
          );
        }
        final visible = items.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < visible.length; i++)
              _FamDashCaseCard(
                data: visible[i],
                onTap: () =>
                    ref.read(portalTabProvider.notifier).state = 1,
              )
                  .animate(delay: (i * 50).ms)
                  .fadeIn(duration: 240.ms)
                  .slideY(begin: 0.06, curve: Curves.easeOutCubic),
          ],
        );
      },
    );
  }
}

class _FamDashCaseCard extends StatelessWidget {
  const _FamDashCaseCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    final name = (data['missing_person_name'] as String?) ?? 'Unknown';
    final caseId = (data['case_id'] as String?) ?? '—';
    final status = (data['status'] as String?) ?? 'Pending';
    final priority = (data['priority'] as String?) ?? 'Medium';
    final lastSeen = (data['last_seen_location'] as String?) ?? '—';
    final elapsed = _famDashElapsed(data['reported_at'] as String?);
    final statusColor = _famDashStatusColor(status);

    return AppCard(
      onTap: onTap,
      accentColor: _famDashPriorityColor(priority),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(name, size: 52, statusDot: statusColor),
              const SizedBox(width: AppSpacing.md),
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
                    Text(
                      '$caseId  •  $lastSeen',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right,
                  size: 22, color: scheme.onSurfaceVariant),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: _famDashProgress(status),
              minHeight: 5,
              color: statusColor,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Notifications preview
// ============================================================
class _FamDashNotifPreview extends StatelessWidget {
  const _FamDashNotifPreview();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FamDashNotifTile(
          accent: AppColors.accent,
          container: AppColors.accentContainer,
          icon: Symbols.visibility,
          title: 'Possible sighting reported',
          body: 'A volunteer reported a possible sighting near Sector 4 '
              'Ghats. Verification is underway.',
          time: '25m ago',
        ),
        _FamDashNotifTile(
          accent: AppColors.hospital,
          container: AppColors.hospitalContainer,
          icon: Symbols.smart_toy,
          title: 'AI match found',
          body: 'CCTV camera 142 captured a probable match. Tap to review '
              'the candidates.',
          time: '1h ago',
        ),
      ],
    );
  }
}

class _FamDashNotifTile extends StatelessWidget {
  const _FamDashNotifTile({
    required this.accent,
    required this.container,
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
  });

  final Color accent;
  final Color container;
  final IconData icon;
  final String title;
  final String body;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    return AppCard(
      accentColor: accent,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: container, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      time,
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/ai_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_providers.dart';
import '../family/screens/aadhaar_scanner_screen.dart';
import '../family/screens/ai_interview_screen.dart';
import '../family/screens/complaint_tracker_screen.dart';
import '../family/screens/family_dashboard.dart';
import '../family/screens/family_notifications_screen.dart';
import '../family/screens/register_missing_person_screen.dart';
import '../family/screens/voice_recording_screen.dart';
import '../police/screens/active_cases_screen.dart';
import '../police/screens/face_match_screen.dart';
import '../police/screens/police_dashboard.dart';
import '../admin/screens/admin_dashboard.dart';
import '../settings/screens/ai_settings_screen.dart';
import '../volunteer/screens/assigned_case_screen.dart';
import '../volunteer/screens/found_person_face_scan.dart';
import '../volunteer/screens/navigation_map_screen.dart';
import '../volunteer/screens/recent_assignments_screen.dart';
import '../volunteer/screens/shift_checkin_screen.dart';
import '../volunteer/screens/sos_emergency_screen.dart';
import '../volunteer/screens/task_history_screen.dart';
import '../volunteer/screens/upload_observation_screen.dart';
import '../volunteer/screens/volunteer_dashboard.dart';
import '../volunteer/screens/volunteer_profile_screen.dart';

/// Role-aware portal shell. Each Stitch screen is a complete Scaffold, so the
/// shell hosts them in an [IndexedStack] and provides cross-screen navigation
/// (bottom nav on mobile portals, navigation rail on the desktop portals) plus
/// a shared overflow menu (other screens + logout).
class PortalHomeScreen extends ConsumerStatefulWidget {
  const PortalHomeScreen({super.key});

  @override
  ConsumerState<PortalHomeScreen> createState() => _PortalHomeScreenState();
}

class _PortalHomeScreenState extends ConsumerState<PortalHomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Kick off on-device model init (Gemma / face) once per session.
    ref.watch(aiBootstrapProvider);
    final role = ref.watch(authStateProvider).user?.role ?? UserRole.family;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final tabs = _tabsFor(role);
    final rawIndex = ref.watch(portalTabProvider);
    final index = rawIndex.clamp(0, tabs.length - 1);

    final body = IndexedStack(
      index: index,
      children: [for (final t in tabs) t.screen],
    );

    // Desktop-first portals (police/admin) use a navigation rail on wide screens.
    if (role.isDesktopPortal && !isMobile) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => ref.read(portalTabProvider.notifier).state = i,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surfaceContainerLow,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Symbols.logout, color: AppColors.error),
                  onPressed: () => _confirmLogout(context),
                ),
              ),
              destinations: [
                for (final t in tabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.icon, fill: 1),
                    label: Text(t.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Mobile portals (family/volunteer): bottom navigation with logout action.
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/icons/app_icon.png',
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Symbols.temple_hindu,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'KumbhSathi AI',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.hairline,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Symbols.logout, size: 22, color: AppColors.danger),
            onPressed: () => _confirmLogout(context),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i == tabs.length - 1 && (role == UserRole.family || role == UserRole.volunteer)) {
            _showMore(context, role);
          } else {
            ref.read(portalTabProvider.notifier).state = i;
          }
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.icon, fill: 1),
              label: t.label,
            ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog before logging out.
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.modal),
        ),
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? Any pending offline data will sync when you log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(authStateProvider.notifier).logout();
    }
  }

  void _showMore(BuildContext context, UserRole role) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final extra in _extrasFor(role))
              ListTile(
                leading: Icon(extra.icon, color: AppColors.primary),
                title: Text(extra.label),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => extra.screen),
                  );
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Symbols.logout, color: AppColors.error),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_Tab> _tabsFor(UserRole role) {
    switch (role) {
      case UserRole.family:
        return const [
          _Tab('Home', Symbols.home, FamilyDashboardScreen()),
          _Tab('Track', Symbols.location_on, ComplaintTrackerScreen()),
          _Tab('Alerts', Symbols.notifications, FamilyNotificationsScreen()),
          _Tab('More', Symbols.menu, SizedBox.shrink()),
        ];
      case UserRole.volunteer:
        return const [
          _Tab('Dashboard', Symbols.dashboard, VolunteerDashboardScreen()),
          _Tab('Assignments', Symbols.assignment, RecentAssignmentsScreen()),
          _Tab('Tasks', Symbols.checklist, TaskHistoryScreen()),
          _Tab('Map', Symbols.map, NavigationMapScreen()),
          _Tab('More', Symbols.menu, SizedBox.shrink()),
        ];
      case UserRole.police:
        return const [
          _Tab('Dashboard', Symbols.dashboard, PoliceDashboardScreen()),
          _Tab('Cases', Symbols.folder_open, ActiveCasesScreen()),
          _Tab('Face Match', Symbols.face, FaceMatchScreen()),
          _Tab('AI & Models', Symbols.neurology, AiSettingsScreen()),
        ];
      case UserRole.admin:
        return const [
          _Tab('Dashboard', Symbols.dashboard, AdminDashboardScreen()),
          _Tab('Live Map', Symbols.map, NavigationMapScreen()),
          _Tab('AI & Models', Symbols.neurology, AiSettingsScreen()),
        ];
    }
  }

  /// Secondary screens surfaced through the "More" sheet on mobile portals.
  List<_Tab> _extrasFor(UserRole role) {
    switch (role) {
      case UserRole.family:
        return const [
          _Tab('Report Missing Person', Symbols.person_add, RegisterMissingPersonScreen()),
          _Tab('AI Guided Interview', Symbols.smart_toy, AiInterviewScreen()),
          _Tab('Voice Recording', Symbols.mic, VoiceRecordingScreen()),
          _Tab('Aadhaar Scanner', Symbols.id_card, AadhaarScannerScreen()),
          _Tab('AI & Models', Symbols.neurology, AiSettingsScreen()),
        ];
      case UserRole.volunteer:
        return const [
          _Tab('Assigned Case', Symbols.assignment_ind, AssignedCaseScreen()),
          _Tab('Found Person — Face Scan', Symbols.familiar_face_and_zone,
              FoundPersonFaceScanScreen()),
          _Tab('Report Observation', Symbols.add_a_photo, UploadObservationScreen()),
          _Tab('Shift Check-In', Symbols.login, ShiftCheckinScreen()),
          _Tab('SOS Emergency', Symbols.emergency, SosEmergencyScreen()),
          _Tab('My Profile', Symbols.person, VolunteerProfileScreen()),
          _Tab('AI & Models', Symbols.neurology, AiSettingsScreen()),
        ];
      case UserRole.police:
      case UserRole.admin:
        return const [];
    }
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.screen);
  final String label;
  final IconData icon;
  final Widget screen;
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/section_header.dart';

/// Command Center Admin Dashboard — Design System v2 "Sanctum" (DESIGN.md §6.4).
///
/// NO internal sidebar — the shell already provides a NavigationRail.
/// Topbar: 'Command Center' + live date/time, search, AiModeChip, bell, avatar.
/// Row 1: 4 KpiCards from dashboardKpiProvider.
/// Row 2: Live ops map (flutter_map v8 + offline fallback) 2/3 + Live Feed 1/3.
/// Row 3: Zone risk table + volunteer load bars.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const _AdminDashTopBar(),
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
                          // ── Row 1: KPI cards ──
                          _AdminDashKpiRow(wide: wide),
                          const SizedBox(height: AppSpacing.xl),

                          // ── Row 2: Map + Live Feed ──
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: const _AdminDashMapCard()
                                      .animate(delay: 200.ms)
                                      .fadeIn(duration: 240.ms)
                                      .slideY(begin: 0.06),
                                ),
                                const SizedBox(width: AppSpacing.xl),
                                Expanded(
                                  child: const _AdminDashLiveFeed()
                                      .animate(delay: 250.ms)
                                      .fadeIn(duration: 240.ms)
                                      .slideY(begin: 0.06),
                                ),
                              ],
                            )
                          else ...[
                            const _AdminDashMapCard()
                                .animate(delay: 200.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06),
                            const SizedBox(height: AppSpacing.xl),
                            const _AdminDashLiveFeed()
                                .animate(delay: 250.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06),
                          ],
                          const SizedBox(height: AppSpacing.xl),

                          // ── Row 3: Zone risk + volunteer loads ──
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: const _AdminDashZoneRiskTable()
                                      .animate(delay: 300.ms)
                                      .fadeIn(duration: 240.ms)
                                      .slideY(begin: 0.06),
                                ),
                                const SizedBox(width: AppSpacing.xl),
                                Expanded(
                                  child: const _AdminDashVolunteerLoads()
                                      .animate(delay: 350.ms)
                                      .fadeIn(duration: 240.ms)
                                      .slideY(begin: 0.06),
                                ),
                              ],
                            )
                          else ...[
                            const _AdminDashZoneRiskTable()
                                .animate(delay: 300.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06),
                            const SizedBox(height: AppSpacing.xl),
                            const _AdminDashVolunteerLoads()
                                .animate(delay: 350.ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(begin: 0.06),
                          ],
                          const SizedBox(height: AppSpacing.xxl),
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

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashTopBar extends ConsumerWidget {
  const _AdminDashTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fullName =
        ref.watch(authStateProvider.select((s) => s.user?.fullName)) ??
            'Admin';
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [
          Text(
            'Command Center',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '$dateStr · $timeStr',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 240,
            height: 38,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search cases, volunteers…',
                prefixIcon: const Icon(Symbols.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                constraints: const BoxConstraints(maxHeight: 38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide.none,
                ),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          const AiModeChip(dense: true),
          const SizedBox(width: AppSpacing.md),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Symbols.notifications,
                  color: theme.colorScheme.onSurfaceVariant),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.base),
          PersonAvatar(fullName, size: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Row
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashKpiRow extends ConsumerWidget {
  const _AdminDashKpiRow({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(dashboardKpiProvider);
    return kpis.when(
      loading: () => Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.base),
            const Expanded(
                child: ShimmerBox(height: 140, radius: AppRadius.card)),
          ],
        ],
      ),
      error: (_, __) => const EmptyState(
        icon: Symbols.error,
        title: 'Could not load statistics',
        subtitle: 'Check your connection and try again.',
      ),
      data: (data) {
        final statusCounts =
            data['status_counts'] as Map<String, dynamic>? ?? {};
        final activeCases =
            ((statusCounts['Pending'] ?? 0) as num).toInt() +
                ((statusCounts['Searching'] ?? 0) as num).toInt();
        final reunited =
            ((statusCounts['Reunited'] ?? 0) as num).toInt();
        final volunteers =
            ((data['available_volunteers'] ?? 0) as num).toInt();
        final dupRate =
            ((data['duplicate_rate'] ?? 0) as num).toDouble();

        final cards = <Widget>[
          KpiCard(
            label: 'Active Cases',
            value: activeCases,
            icon: Symbols.person_search,
            color: AppColors.primary,
            containerColor: AppColors.primaryContainer,
            deltaLabel: '+12 today',
            deltaPositive: false,
            sparkline: const [42, 38, 45, 52, 48, 55, 61],
          ),
          KpiCard(
            label: 'Reunited Today',
            value: reunited,
            icon: Symbols.family_restroom,
            color: AppColors.success,
            containerColor: AppColors.successContainer,
            deltaLabel: '+8.2%',
            deltaPositive: true,
            sparkline: const [150, 162, 170, 180, 185, 190, 195],
          ),
          KpiCard(
            label: 'Volunteers Available',
            value: volunteers,
            icon: Symbols.groups,
            color: AppColors.accent,
            containerColor: AppColors.accentContainer,
            deltaLabel: '92% active',
            deltaPositive: true,
            sparkline: const [800, 820, 810, 835, 840, 845, 850],
          ),
          KpiCard(
            label: 'Duplicate Rate',
            value: dupRate,
            icon: Symbols.content_copy,
            color: AppColors.warning,
            containerColor: AppColors.warningContainer,
            suffix: '%',
            decimals: 1,
            deltaLabel: '−0.3%',
            deltaPositive: true,
            sparkline: const [7.2, 6.8, 6.5, 6.1, 5.9, 5.8, 5.7],
          ),
        ];

        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: cards[i]
                      .animate(delay: (i * 50).ms)
                      .fadeIn(duration: 240.ms)
                      .slideY(begin: 0.06),
                ),
              ],
            ],
          );
        }

        // 2x2 grid for narrow
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: AppSpacing.base),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: AppSpacing.base),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Operations Map
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashMapCard extends ConsumerStatefulWidget {
  const _AdminDashMapCard();

  @override
  ConsumerState<_AdminDashMapCard> createState() => _AdminDashMapCardState();
}

class _AdminDashMapCardState extends ConsumerState<_AdminDashMapCard> {
  bool _showZones = true;
  bool _showStations = true;
  bool _showCctv = true;

  static const _center = LatLng(19.9975, 73.7898);

  static const _zones = <({LatLng center, double radius, Color color, String label})>[
    (center: LatLng(19.999, 73.788), radius: 350, color: AppColors.danger, label: 'Sector 1 — High Risk'),
    (center: LatLng(19.996, 73.792), radius: 280, color: AppColors.warning, label: 'Sector 2 — Medium'),
    (center: LatLng(19.994, 73.785), radius: 200, color: AppColors.success, label: 'Sector 3 — Low'),
    (center: LatLng(20.001, 73.795), radius: 300, color: AppColors.warning, label: 'Railway — Medium'),
  ];

  static const _stations = <({LatLng pos, String label})>[
    (pos: LatLng(19.998, 73.790), label: 'Main Police Station'),
    (pos: LatLng(19.995, 73.786), label: 'Sector 3 Outpost'),
  ];

  static const _cameras = <({LatLng pos, String label})>[
    (pos: LatLng(19.999, 73.793), label: 'CCTV Ghat Road'),
    (pos: LatLng(19.997, 73.787), label: 'CCTV Sector 2 Entry'),
    (pos: LatLng(20.000, 73.791), label: 'CCTV Transit Hub'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = ref.watch(isOnlineProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Live Operations Map',
            icon: Symbols.map,
          ),
          // Toggle chips
          Row(
            children: [
              _AdminDashToggleChip(
                label: 'Zones',
                selected: _showZones,
                onSelected: (v) => setState(() => _showZones = v),
              ),
              const SizedBox(width: AppSpacing.sm),
              _AdminDashToggleChip(
                label: 'Stations',
                selected: _showStations,
                onSelected: (v) => setState(() => _showStations = v),
              ),
              const SizedBox(width: AppSpacing.sm),
              _AdminDashToggleChip(
                label: 'CCTV',
                selected: _showCctv,
                onSelected: (v) => setState(() => _showCctv = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 380,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: online ? _buildMap(theme) : _buildOfflineFallback(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(ThemeData theme) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kumbhsathi.app',
        ),
        if (_showZones)
          CircleLayer(
            circles: [
              for (final z in _zones)
                CircleMarker(
                  point: z.center,
                  radius: z.radius / 4,
                  color: z.color.withValues(alpha: 0.18),
                  borderColor: z.color.withValues(alpha: 0.5),
                  borderStrokeWidth: 2,
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (_showStations)
              for (final s in _stations)
                Marker(
                  point: s.pos,
                  width: 32,
                  height: 32,
                  child: Tooltip(
                    message: s.label,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryDeep,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Symbols.shield, size: 16,
                          color: Colors.white),
                    ),
                  ),
                ),
            if (_showCctv)
              for (final c in _cameras)
                Marker(
                  point: c.pos,
                  width: 28,
                  height: 28,
                  child: Tooltip(
                    message: c.label,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Symbols.videocam, size: 14,
                          color: Colors.white),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _buildOfflineFallback(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: CustomPaint(
        painter: _AdminDashGridPainter(theme.colorScheme.outlineVariant),
        child: Stack(
          children: [
            // Approximate markers
            for (final s in _stations)
              if (_showStations)
                Positioned(
                  left: _lngToX(s.pos.longitude) - 14,
                  top: _latToY(s.pos.latitude) - 14,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDeep,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Symbols.shield, size: 14,
                        color: Colors.white),
                  ),
                ),
            for (final c in _cameras)
              if (_showCctv)
                Positioned(
                  left: _lngToX(c.pos.longitude) - 12,
                  top: _latToY(c.pos.latitude) - 12,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.info,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Symbols.videocam, size: 12,
                        color: Colors.white),
                  ),
                ),
            // Offline label
            Positioned(
              bottom: AppSpacing.md,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Offline map — approximate positions',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onWarningContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Rough projection for offline fallback (Nasik/Kumbh area)
  double _lngToX(double lng) => ((lng - 73.78) / 0.02) * 380;
  double _latToY(double lat) => ((20.005 - lat) / 0.015) * 380;
}

class _AdminDashGridPainter extends CustomPainter {
  _AdminDashGridPainter(this.lineColor);
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_AdminDashGridPainter old) => lineColor != old.lineColor;
}

class _AdminDashToggleChip extends StatelessWidget {
  const _AdminDashToggleChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Feed
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashLiveFeed extends ConsumerWidget {
  const _AdminDashLiveFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(auditLogProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.rss_feed, size: 20,
                  color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Live Feed',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const _AdminDashPulsingLiveChip(),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            height: 360,
            child: logsAsync.when(
              loading: () => const ShimmerList(items: 5, itemHeight: 56),
              error: (_, __) => const EmptyState(
                icon: Symbols.feed,
                title: 'No events loaded',
                subtitle: 'Feed will populate when data is available.',
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return const EmptyState(
                    icon: Symbols.feed,
                    title: 'No recent events',
                    subtitle: 'System events will appear here.',
                  );
                }
                return ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final log = logs[i];
                    final severity =
                        (log['severity'] ?? 'info').toString();
                    final action =
                        (log['action'] ?? '').toString();
                    final createdAt = DateTime.tryParse(
                        (log['created_at'] ?? '').toString());
                    final timeAgo = createdAt != null
                        ? _adminDashRelativeTime(createdAt)
                        : '';
                    final dotColor = switch (severity) {
                      'critical' => AppColors.danger,
                      'warning' => AppColors.warning,
                      _ => AppColors.info,
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                          fontWeight:
                                              FontWeight.w500),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeAgo,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(
                                        color: theme.colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDashPulsingLiveChip extends StatefulWidget {
  const _AdminDashPulsingLiveChip();

  @override
  State<_AdminDashPulsingLiveChip> createState() =>
      _AdminDashPulsingLiveChipState();
}

class _AdminDashPulsingLiveChipState
    extends State<_AdminDashPulsingLiveChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.accentContainer,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.5 + _ctrl.value * 0.5,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'LIVE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.accentDeep,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zone Risk Table
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashZoneRiskTable extends StatelessWidget {
  const _AdminDashZoneRiskTable();

  static const _zones = <Map<String, dynamic>>[
    {
      'zone': 'Sector 1 — Main Ghat',
      'risk': 'Critical',
      'active': 23,
      'volunteers': 45,
      'coverage': 92,
    },
    {
      'zone': 'Sector 2 — Dormitories',
      'risk': 'High',
      'active': 15,
      'volunteers': 30,
      'coverage': 78,
    },
    {
      'zone': 'Sector 3 — Temple Complex',
      'risk': 'Medium',
      'active': 8,
      'volunteers': 22,
      'coverage': 85,
    },
    {
      'zone': 'Sector 4 — Transit Hub',
      'risk': 'High',
      'active': 18,
      'volunteers': 28,
      'coverage': 65,
    },
    {
      'zone': 'Railway Station Area',
      'risk': 'Medium',
      'active': 6,
      'volunteers': 15,
      'coverage': 72,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Zone Risk Analysis', icon: Symbols.warning),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: AppSpacing.xl,
              columns: const [
                DataColumn(label: Text('Zone')),
                DataColumn(label: Text('Risk')),
                DataColumn(label: Text('Active'), numeric: true),
                DataColumn(label: Text('Volunteers'), numeric: true),
                DataColumn(label: Text('Coverage %'), numeric: true),
              ],
              rows: [
                for (final z in _zones)
                  DataRow(cells: [
                    DataCell(Text(
                      z['zone'] as String,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    )),
                    DataCell(_AdminDashRiskPill(z['risk'] as String)),
                    DataCell(Text('${z['active']}')),
                    DataCell(Text('${z['volunteers']}')),
                    DataCell(Text('${z['coverage']}%')),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDashRiskPill extends StatelessWidget {
  const _AdminDashRiskPill(this.level);
  final String level;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (level) {
      'Critical' => (AppColors.danger, AppColors.dangerContainer),
      'High' => (AppColors.accentDeep, AppColors.accentContainer),
      'Medium' => (AppColors.warning, AppColors.warningContainer),
      _ => (AppColors.success, AppColors.successContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            level,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Volunteer Load Bars
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashVolunteerLoads extends StatelessWidget {
  const _AdminDashVolunteerLoads();

  static const _volunteers = <({String name, double load, int cases})>[
    (name: 'Rajesh Patel', load: 0.85, cases: 4),
    (name: 'Meena Sharma', load: 0.72, cases: 3),
    (name: 'Vikram Singh', load: 0.95, cases: 5),
    (name: 'Anita Devi', load: 0.60, cases: 2),
    (name: 'Suresh Kumar', load: 0.45, cases: 1),
    (name: 'Priya Gupta', load: 0.78, cases: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Volunteer Load', icon: Symbols.groups),
          for (var i = 0; i < _volunteers.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _AdminDashVolunteerLoadItem(v: _volunteers[i]),
          ],
        ],
      ),
    );
  }
}

class _AdminDashVolunteerLoadItem extends StatelessWidget {
  const _AdminDashVolunteerLoadItem({required this.v});
  final ({String name, double load, int cases}) v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadColor = v.load >= 0.9
        ? AppColors.danger
        : v.load >= 0.7
            ? AppColors.warning
            : AppColors.success;

    return Row(
      children: [
        PersonAvatar(v.name, size: 28),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    v.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${v.cases} cases · ${(v.load * 100).toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: v.load,
                  minHeight: 6,
                  color: loadColor,
                  backgroundColor: loadColor.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _adminDashRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

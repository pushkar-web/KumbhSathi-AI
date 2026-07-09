import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../shared/widgets/animated_count.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/status_badge.dart';

// ---------------------------------------------------------------------------
// Geo anchors — Nashik / Ramkund search sector (DESIGN.md §6.3).
// ---------------------------------------------------------------------------
const LatLng _navCenter = LatLng(19.9975, 73.7898);
const LatLng _navVolunteerPos = LatLng(19.9941, 73.7869);
const LatLng _navLastSeenPos = LatLng(20.0021, 73.7934);
const LatLng _navPolicePos = LatLng(19.9998, 73.7841);
const LatLng _navCctvAPos = LatLng(19.9992, 73.7952);
const LatLng _navCctvBPos = LatLng(19.9948, 73.7921);
const List<LatLng> _navRoutePoints = [
  _navVolunteerPos,
  LatLng(19.9957, 73.7892),
  LatLng(19.9989, 73.7907),
  _navLastSeenPos,
];

/// Volunteer search-navigation map (DESIGN.md §6.3). Live OpenStreetMap tiles
/// when online; a styled approximate-position fallback when offline or when
/// tile loading fails. All overlay UI (status card, layer toggles, route
/// sheet) renders identically in both modes.
class NavigationMapScreen extends ConsumerStatefulWidget {
  const NavigationMapScreen({super.key});

  @override
  ConsumerState<NavigationMapScreen> createState() =>
      _NavigationMapScreenState();
}

class _NavigationMapScreenState extends ConsumerState<NavigationMapScreen> {
  final MapController _mapController = MapController();

  bool _ready = false;
  bool _loadError = false;
  bool _tilesFailed = false;
  bool _showCctv = true;
  bool _showPolice = true;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Simulated route preparation — shows the skeleton that mirrors the final
  /// layout while local assignment data is read.
  void _loadRoute() {
    setState(() {
      _ready = false;
      _loadError = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      try {
        setState(() => _ready = true);
      } catch (_) {
        setState(() => _loadError = true);
      }
    });
  }

  void _handleTileError() {
    if (_tilesFailed || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tilesFailed) setState(() => _tilesFailed = true);
    });
  }

  void _recenter() {
    try {
      _mapController.move(_navVolunteerPos, 15.2);
    } catch (_) {
      // Controller not attached (offline fallback active) — ignore.
    }
  }

  void _zoomBy(double delta) {
    try {
      final camera = _mapController.camera;
      _mapController.move(camera.center, camera.zoom + delta);
    } catch (_) {
      // Controller not attached — ignore.
    }
  }

  void _toggleNavigation() {
    setState(() => _navigating = !_navigating);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _navigating
              ? 'Guidance started — 850 m via Ghat Road'
              : 'Guidance ended',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: _buildBody(online)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool online) {
    if (_loadError) {
      return EmptyState(
        icon: Symbols.wrong_location,
        title: 'Couldn’t load the search route',
        subtitle: 'Your assignment data is safe. Try loading the map again.',
        actionLabel: 'Retry',
        onAction: _loadRoute,
      );
    }
    if (!_ready) return const _NavMapShimmer();

    final liveMap = online && !_tilesFailed;
    return Stack(
      children: [
        Positioned.fill(
          child: liveMap
              ? _buildLiveMap()
              : _NavOfflineMap(showCctv: _showCctv, showPolice: _showPolice),
        ),
        // Top search / status card.
        Positioned(
          top: AppSpacing.md,
          left: AppSpacing.base,
          right: AppSpacing.base,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _NavTopCard()
                  .animate()
                  .fadeIn(duration: 240.ms)
                  .slideY(begin: -0.06),
              if (!liveMap)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Center(
                    child: _NavOfflineChip(
                      label: online
                          ? 'Map tiles unavailable — approximate positions'
                          : 'Offline map — approximate positions',
                    ),
                  ),
                ).animate().fadeIn(duration: 240.ms, delay: 100.ms),
            ],
          ),
        ),
        // Floating layer-toggle column.
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.base),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavMapControl(
                  icon: Symbols.videocam,
                  tooltip: 'CCTV cameras',
                  active: _showCctv,
                  onTap: () => setState(() => _showCctv = !_showCctv),
                ),
                const SizedBox(height: AppSpacing.sm),
                _NavMapControl(
                  icon: Symbols.shield,
                  tooltip: 'Police stations',
                  active: _showPolice,
                  onTap: () => setState(() => _showPolice = !_showPolice),
                ),
                const SizedBox(height: AppSpacing.sm),
                _NavMapControl(
                  icon: Symbols.my_location,
                  tooltip: 'Recenter',
                  onTap: _recenter,
                ),
                if (liveMap) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _NavMapControl(
                    icon: Symbols.add,
                    tooltip: 'Zoom in',
                    onTap: () => _zoomBy(1),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _NavMapControl(
                    icon: Symbols.remove,
                    tooltip: 'Zoom out',
                    onTap: () => _zoomBy(-1),
                  ),
                ],
              ],
            )
                .animate()
                .fadeIn(duration: 240.ms, delay: 100.ms)
                .slideX(begin: 0.12),
          ),
        ),
        // Bottom route sheet.
        Align(
          alignment: Alignment.bottomCenter,
          child: _NavRouteCard(
            navigating: _navigating,
            onStart: _toggleNavigation,
          ).animate().fadeIn(duration: 240.ms, delay: 50.ms).slideY(begin: 0.1),
        ),
      ],
    );
  }

  Widget _buildLiveMap() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _navCenter,
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kumbhsathi.app',
          errorTileCallback: (tile, error, stackTrace) => _handleTileError(),
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: _navRoutePoints,
              strokeWidth: 5,
              color: AppColors.primary.withValues(alpha: 0.85),
              borderStrokeWidth: 2,
              borderColor: Colors.white,
              pattern: StrokePattern.dashed(segments: const [16, 10]),
            ),
          ],
        ),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    return [
      if (_showPolice)
        const Marker(
          point: _navPolicePos,
          width: 38,
          height: 38,
          child: _NavPoliceMarker(),
        ),
      if (_showCctv) ...[
        const Marker(
          point: _navCctvAPos,
          width: 30,
          height: 30,
          child: _NavCctvMarker(),
        ),
        const Marker(
          point: _navCctvBPos,
          width: 30,
          height: 30,
          child: _NavCctvMarker(),
        ),
      ],
      const Marker(
        point: _navLastSeenPos,
        width: 56,
        height: 58,
        alignment: Alignment.topCenter,
        child: _NavLastSeenMarker(),
      ),
      const Marker(
        point: _navVolunteerPos,
        width: 52,
        height: 52,
        child: _NavVolunteerMarker(),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton — mirrors map + top card + bottom sheet.
// ---------------------------------------------------------------------------
class _NavMapShimmer extends StatelessWidget {
  const _NavMapShimmer();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(
          child: ShimmerBox(height: double.infinity, radius: 0),
        ),
        Positioned(
          top: AppSpacing.md,
          left: AppSpacing.base,
          right: AppSpacing.base,
          child: ShimmerBox(height: 128, radius: AppRadius.card),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ShimmerBox(height: 150, radius: AppRadius.sheet),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top search / status card.
// ---------------------------------------------------------------------------
class _NavTopCard extends StatelessWidget {
  const _NavTopCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;

    return AppCard(
      raised: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Search Navigation',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const StatusBadge.fromLabel('Searching'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Destination "search" well.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Row(
              children: [
                const Icon(Symbols.location_on,
                    size: 18, color: AppColors.accentDeep),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Ramkund Ghat · last seen 2:35 PM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Symbols.search, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _NavStat(
                  label: 'Distance',
                  child: AnimatedCount(
                    850,
                    suffix: ' m',
                    style:
                        text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _NavStatDivider(color: scheme.outlineVariant),
              Expanded(
                child: _NavStat(
                  label: 'ETA on foot',
                  child: AnimatedCount(
                    12,
                    suffix: ' min',
                    style:
                        text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _NavStatDivider(color: scheme.outlineVariant),
              Expanded(
                child: _NavStat(
                  label: 'Zone',
                  child: Text(
                    'Sector 4',
                    style:
                        text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavStat extends StatelessWidget {
  const _NavStat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        child,
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _NavStatDivider extends StatelessWidget {
  const _NavStatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: color,
    );
  }
}

// ---------------------------------------------------------------------------
// Floating map control button (48px touch target).
// ---------------------------------------------------------------------------
class _NavMapControl extends StatelessWidget {
  const _NavMapControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// null = plain action button; true/false = toggle state.
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = active ?? false;

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(
            color: isActive
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.outlineVariant,
          ),
          boxShadow: AppShadows.raised,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.input),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(
              icon,
              size: 22,
              fill: isActive ? 1 : 0,
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom route sheet card.
// ---------------------------------------------------------------------------
class _NavRouteCard extends StatelessWidget {
  const _NavRouteCard({required this.navigating, required this.onStart});

  final bool navigating;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.raised,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.base,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentContainer,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: const Icon(Symbols.route,
                    size: 24, color: AppColors.accentDeep),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '850 m · 12 min walk',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      navigating
                          ? 'Guidance active · via Ghat Road'
                          : 'via Ghat Road · avoids dense crowd',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              PrimaryCta(
                label: navigating ? 'End' : 'Start',
                icon: navigating ? Symbols.stop_circle : Symbols.navigation,
                expanded: false,
                onPressed: onStart,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Markers (shared by live map + offline fallback).
// ---------------------------------------------------------------------------
class _NavVolunteerMarker extends StatelessWidget {
  const _NavVolunteerMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing halo.
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              begin: const Offset(0.4, 0.4),
              end: const Offset(1, 1),
              duration: 1500.ms,
              curve: Curves.easeOutCubic,
            )
            .fadeOut(duration: 1500.ms, curve: Curves.easeOut),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: AppShadows.card,
          ),
        ),
      ],
    );
  }
}

class _NavLastSeenMarker extends StatelessWidget {
  const _NavLastSeenMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 2.5),
            boxShadow: AppShadows.card,
          ),
          child: const PersonAvatar('Asha Devi', size: 36),
        ),
        CustomPaint(
          size: const Size(12, 7),
          painter: _NavPinTipPainter(),
        ),
      ],
    );
  }
}

class _NavPinTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.accent;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavPoliceMarker extends StatelessWidget {
  const _NavPoliceMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primaryDeep,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppShadows.card,
      ),
      child: const Icon(Symbols.shield, fill: 1, size: 18, color: Colors.white),
    );
  }
}

class _NavCctvMarker extends StatelessWidget {
  const _NavCctvMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.infoContainer,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.info, width: 1.5),
        boxShadow: AppShadows.card,
      ),
      child: const Icon(Symbols.videocam, size: 15, color: AppColors.info),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline fallback map — sunken surface, subtle grid, approximate markers.
// ---------------------------------------------------------------------------
class _NavOfflineMap extends StatelessWidget {
  const _NavOfflineMap({required this.showCctv, required this.showPolice});

  final bool showCctv;
  final bool showPolice;

  /// Maps a coordinate to an approximate [Alignment] inside the viewport.
  static Alignment _alignFor(LatLng point) {
    final x = (point.longitude - _navCenter.longitude) / 0.0075;
    final y = (_navCenter.latitude - point.latitude) / 0.009;
    return Alignment(x.clamp(-0.85, 0.85), y.clamp(-0.7, 0.5));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerHigh,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _NavOfflineGridPainter(
                gridColor: scheme.outlineVariant.withValues(alpha: 0.55),
                roadColor: scheme.surface.withValues(alpha: 0.75),
                routeColor: AppColors.primary.withValues(alpha: 0.8),
                route: [for (final p in _navRoutePoints) _alignFor(p)],
              ),
            ),
          ),
          if (showPolice)
            Align(
              alignment: _alignFor(_navPolicePos),
              child: const _NavPoliceMarker(),
            ),
          if (showCctv) ...[
            Align(
              alignment: _alignFor(_navCctvAPos),
              child: const _NavCctvMarker(),
            ),
            Align(
              alignment: _alignFor(_navCctvBPos),
              child: const _NavCctvMarker(),
            ),
          ],
          Align(
            alignment: _alignFor(_navLastSeenPos),
            child: const _NavLastSeenMarker(),
          ),
          Align(
            alignment: _alignFor(_navVolunteerPos),
            child: const _NavVolunteerMarker(),
          ),
        ],
      ),
    );
  }
}

/// Warning-tonal pill flagging approximate offline positions.
class _NavOfflineChip extends StatelessWidget {
  const _NavOfflineChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.map, size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onWarningContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Subtle street-grid + dashed route painter for the offline fallback.
class _NavOfflineGridPainter extends CustomPainter {
  const _NavOfflineGridPainter({
    required this.gridColor,
    required this.roadColor,
    required this.routeColor,
    required this.route,
  });

  final Color gridColor;
  final Color roadColor;
  final Color routeColor;
  final List<Alignment> route;

  Offset _toOffset(Alignment a, Size size) =>
      Offset((a.x + 1) / 2 * size.width, (a.y + 1) / 2 * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    // Fine grid.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const step = 44.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // A couple of broad "roads" for texture.
    final road = Paint()
      ..color = roadColor
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.78),
      Offset(size.width * 0.92, size.height * 0.22),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.3),
      Offset(size.width * 0.95, size.height * 0.42),
      road,
    );

    // Dashed route between approximate marker positions.
    if (route.length < 2) return;
    final routePaint = Paint()
      ..color = routeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final first = _toOffset(route.first, size);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final a in route.skip(1)) {
      final o = _toOffset(a, size);
      path.lineTo(o.dx, o.dy);
    }
    const dashWidth = 10.0;
    const dashSpace = 8.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          routePaint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NavOfflineGridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor ||
      oldDelegate.roadColor != roadColor ||
      oldDelegate.routeColor != routeColor;
}

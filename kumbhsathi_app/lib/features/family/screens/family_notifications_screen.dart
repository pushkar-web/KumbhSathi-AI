import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';

/// Family notifications — Design System v2 "Sanctum" (DESIGN.md §6.1).
/// Filter chips, Today/Earlier grouping, type-accented cards and
/// swipe-to-mark-read. Data is mocked locally (offline-first preview).
class FamilyNotificationsScreen extends StatefulWidget {
  const FamilyNotificationsScreen({super.key});

  @override
  State<FamilyNotificationsScreen> createState() =>
      _FamilyNotificationsScreenState();
}

class _FamilyNotificationsScreenState
    extends State<FamilyNotificationsScreen> {
  static const _filters = ['All', 'Updates', 'AI Matches', 'System'];

  int _filterIndex = 0;
  bool _loading = true;
  late final List<_FamNotifItem> _items;
  final Set<int> _readIds = {6, 7};

  @override
  void initState() {
    super.initState();
    _items = _famNotifMockItems();
    // Simulated fetch so the shimmer skeleton mirrors the final layout.
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  List<_FamNotifItem> get _filtered {
    final type = switch (_filterIndex) {
      1 => _FamNotifType.update,
      2 => _FamNotifType.aiMatch,
      3 => _FamNotifType.system,
      _ => null,
    };
    if (type == null) return _items;
    return _items.where((n) => n.type == type).toList();
  }

  void _markRead(int id) => setState(() => _readIds.add(id));

  void _markAllRead() =>
      setState(() => _readIds.addAll(_items.map((n) => n.id)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: _loading ? _buildLoading() : _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutterMobile,
        AppSpacing.lg,
        AppSpacing.gutterMobile,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 180, height: 26, radius: AppRadius.chip),
          SizedBox(height: AppSpacing.sm),
          ShimmerBox(width: 240, height: 14, radius: AppRadius.chip),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 40, radius: AppRadius.pill)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: ShimmerBox(height: 40, radius: AppRadius.pill)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: ShimmerBox(height: 40, radius: AppRadius.pill)),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          ShimmerList(items: 4, itemHeight: 104),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    final filtered = _filtered;
    final today = filtered
        .where((n) =>
            n.time.year == now.year &&
            n.time.month == now.month &&
            n.time.day == now.day)
        .toList();
    final earlier = filtered.where((n) => !today.contains(n)).toList();
    final unread =
        _items.where((n) => !_readIds.contains(n.id)).length;

    var cardIndex = 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutterMobile,
        AppSpacing.lg,
        AppSpacing.gutterMobile,
        AppSpacing.xl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unread == 0
                        ? 'You are all caught up'
                        : '$unread unread update${unread == 1 ? '' : 's'} on your cases',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: unread == 0 ? null : _markAllRead,
              icon: const Icon(Symbols.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
          ],
        ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.base),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _filters.length; i++) ...[
                _FamNotifFilterChip(
                  label: _filters[i],
                  selected: _filterIndex == i,
                  onTap: () => setState(() => _filterIndex = i),
                ),
                if (i < _filters.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        )
            .animate(delay: 60.ms)
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: EmptyState(
              icon: Symbols.notifications_off,
              title: 'No notifications here',
              subtitle:
                  'Nothing matches this filter yet. New updates will appear '
                  'as your case progresses.',
              actionLabel: 'Show all',
              onAction: () => setState(() => _filterIndex = 0),
            ),
          )
        else ...[
          if (today.isNotEmpty) ...[
            const _FamNotifGroupLabel('TODAY'),
            for (final n in today)
              _buildCard(n, cardIndex++),
          ],
          if (earlier.isNotEmpty) ...[
            const _FamNotifGroupLabel('EARLIER'),
            for (final n in earlier)
              _buildCard(n, cardIndex++),
          ],
        ],
      ],
    );
  }

  Widget _buildCard(_FamNotifItem n, int index) {
    final card = _FamNotifCard(
      item: n,
      read: _readIds.contains(n.id),
      onMarkRead: () => _markRead(n.id),
    );
    if (index >= 6) return card;
    return card
        .animate(delay: (index * 50).ms)
        .fadeIn(duration: 240.ms)
        .slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }
}

// ============================================================
// Mock data
// ============================================================
enum _FamNotifType { update, aiMatch, system }

class _FamNotifItem {
  const _FamNotifItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.actionLabel,
  });

  final int id;
  final _FamNotifType type;
  final String title;
  final String body;
  final DateTime time;
  final String? actionLabel;
}

List<_FamNotifItem> _famNotifMockItems() {
  final now = DateTime.now();
  return [
    _FamNotifItem(
      id: 1,
      type: _FamNotifType.update,
      title: 'Possible sighting reported',
      body: 'A volunteer reported a possible sighting near Sector 4 Ghats. '
          'Officer verification is underway.',
      time: now.subtract(const Duration(minutes: 25)),
      actionLabel: 'View case',
    ),
    _FamNotifItem(
      id: 2,
      type: _FamNotifType.aiMatch,
      title: 'AI face match — 87% confidence',
      body: 'CCTV camera 142 captured a probable match for Aarav Kumar near '
          'the Triveni Sangam gate at 12:45 PM.',
      time: now.subtract(const Duration(hours: 1, minutes: 10)),
      actionLabel: 'Review match',
    ),
    _FamNotifItem(
      id: 3,
      type: _FamNotifType.system,
      title: 'Volunteer assigned',
      body: 'Amit Singh (VOL-0342) has been assigned to case KMP-2027-02501 '
          'by Officer Sharma.',
      time: now.subtract(const Duration(hours: 3)),
    ),
    _FamNotifItem(
      id: 4,
      type: _FamNotifType.update,
      title: 'Search zone expanded',
      body: 'The search radius was widened to Sectors 3–5 based on AI '
          'movement prediction.',
      time: now.subtract(const Duration(days: 1, hours: 2)),
    ),
    _FamNotifItem(
      id: 5,
      type: _FamNotifType.aiMatch,
      title: 'New AI match candidates',
      body: 'Two lower-confidence matches were found in the evening CCTV '
          'sweep and queued for police review.',
      time: now.subtract(const Duration(days: 1, hours: 6)),
    ),
    _FamNotifItem(
      id: 6,
      type: _FamNotifType.system,
      title: 'Case registered',
      body: 'Your missing person report for Aarav Kumar was recorded. '
          'Case ID KMP-2027-02501.',
      time: now.subtract(const Duration(days: 2, hours: 1)),
    ),
    _FamNotifItem(
      id: 7,
      type: _FamNotifType.system,
      title: 'Welcome to KumbhSathi',
      body: 'Track live updates, AI matches and volunteer activity for your '
          'cases right here.',
      time: now.subtract(const Duration(days: 3)),
    ),
  ];
}

({Color accent, Color container, IconData icon, String label}) _famNotifStyle(
    _FamNotifType type) {
  return switch (type) {
    _FamNotifType.update => (
        accent: AppColors.accent,
        container: AppColors.accentContainer,
        icon: Symbols.visibility,
        label: 'Update',
      ),
    _FamNotifType.aiMatch => (
        accent: AppColors.hospital,
        container: AppColors.hospitalContainer,
        icon: Symbols.smart_toy,
        label: 'AI Match',
      ),
    _FamNotifType.system => (
        accent: AppColors.info,
        container: AppColors.infoContainer,
        icon: Symbols.assignment,
        label: 'System',
      ),
  };
}

String _famNotifTimeLabel(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return DateFormat('d MMM, h:mm a').format(t);
}

// ============================================================
// Widgets
// ============================================================
class _FamNotifGroupLabel extends StatelessWidget {
  const _FamNotifGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
          top: AppSpacing.lg, bottom: AppSpacing.md),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
      ),
    );
  }
}

class _FamNotifFilterChip extends StatelessWidget {
  const _FamNotifFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.exit,
          curve: Curves.easeOut,
          height: 44,
          alignment: Alignment.center,
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _FamNotifCard extends StatelessWidget {
  const _FamNotifCard({
    required this.item,
    required this.read,
    required this.onMarkRead,
  });

  final _FamNotifItem item;
  final bool read;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    final style = _famNotifStyle(item.type);

    return Dismissible(
      key: ValueKey('fam-notif-${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onMarkRead();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.successContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.done_all,
                size: 20, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Mark read',
              style: text.labelMedium?.copyWith(
                color: AppColors.onSuccessContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: Opacity(
        opacity: read ? 0.72 : 1,
        child: AppCard(
          accentColor: style.accent,
          onTap: onMarkRead,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.container,
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, size: 20, color: style.accent),
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
                            item.title,
                            style: text.bodyMedium?.copyWith(
                              fontWeight:
                                  read ? FontWeight.w600 : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _famNotifTimeLabel(item.time),
                          style: text.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (!read) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: style.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.body,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    if (item.actionLabel != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: style.container,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          item.actionLabel!,
                          style: text.labelMedium?.copyWith(
                            color: style.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

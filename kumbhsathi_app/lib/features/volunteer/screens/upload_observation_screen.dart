import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/section_header.dart';

/// Condition of the observed person — maps to semantic colors (DESIGN.md §6.3).
enum _UoCondition {
  safe('Safe', Symbols.health_and_safety),
  distressed('Distressed', Symbols.sentiment_dissatisfied),
  injured('Injured', Symbols.healing),
  unresponsive('Unresponsive', Symbols.personal_injury);

  const _UoCondition(this.label, this.icon);

  final String label;
  final IconData icon;

  Color get color => switch (this) {
        _UoCondition.safe => AppColors.success,
        _UoCondition.distressed => AppColors.warning,
        _UoCondition.injured => AppColors.accentDeep,
        _UoCondition.unresponsive => AppColors.danger,
      };

  Color get container => switch (this) {
        _UoCondition.safe => AppColors.successContainer,
        _UoCondition.distressed => AppColors.warningContainer,
        _UoCondition.injured => AppColors.accentContainer,
        _UoCondition.unresponsive => AppColors.dangerContainer,
      };
}

/// Volunteer "Report Observation" screen (DESIGN.md §6.3): photo capture grid
/// (up to 3), condition chips, auto-detected location card, gender/age quick
/// selects and notes. Submissions queue offline-first through Hive and surface
/// a pending-sync note when the device is offline.
class UploadObservationScreen extends ConsumerStatefulWidget {
  const UploadObservationScreen({super.key});

  @override
  ConsumerState<UploadObservationScreen> createState() =>
      _UploadObservationScreenState();
}

class _UploadObservationScreenState
    extends ConsumerState<UploadObservationScreen> {
  static const _genders = ['Male', 'Female', 'Other'];
  static const _ageRanges = [
    'Child (0–12)',
    'Teen (13–17)',
    'Adult (18–59)',
    'Senior (60+)',
  ];

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];
  final TextEditingController _locationCtrl =
      TextEditingController(text: 'Sector 4, Ramkund');
  final TextEditingController _notesCtrl = TextEditingController();

  _UoCondition? _condition;
  String? _gender;
  String? _ageRange;
  bool _editingLocation = false;
  bool _submitting = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Brief bootstrap (location autofill) behind a layout-matching skeleton.
    Future<void>.delayed(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Photos
  // -------------------------------------------------------------------------
  Future<void> _addPhoto() async {
    if (_photos.length >= 3) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.photo_camera, color: AppColors.primary),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Symbols.photo_library, color: AppColors.primary),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1280);
      if (file == null || !mounted) return;
      setState(() {
        if (_photos.length < 3) _photos.add(file);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t capture the photo. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  // -------------------------------------------------------------------------
  // Submit — offline-first queue (DESIGN.md §8-8)
  // -------------------------------------------------------------------------
  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_condition == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Select the person’s condition first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_photos.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Add at least one photo of the person.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final online = ref.read(isOnlineProvider);

    var queued = false;
    try {
      await ref.read(hiveServiceProvider).queueRequest(
        path: '/api/v1/observations',
        method: 'POST',
        body: {
          'condition': _condition!.name,
          'gender': _gender,
          'age_range': _ageRange,
          'location': _locationCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
          'photos': [for (final p in _photos) p.name],
          'reported_at': DateTime.now().toIso8601String(),
        },
      );
      queued = true;
    } catch (_) {
      queued = false;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!queued) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Couldn’t save the observation. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _showSuccessSheet(online);
  }

  Future<void> _showSuccessSheet(bool online) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmptyState(
                icon: Symbols.check_circle,
                color: AppColors.success,
                title: 'Observation submitted',
                subtitle: online
                    ? 'Shared with the command centre. Nearby teams will be alerted if it matches an active case.'
                    : 'Saved securely on this device and queued for upload.',
              ),
              if (!online)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.base),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Row(
                    children: [
                      const Icon(Symbols.cloud_off,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Pending sync — uploads automatically when back online',
                          style:
                              Theme.of(sheetContext).textTheme.labelMedium?.copyWith(
                                    color: AppColors.onWarningContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              PrimaryCta(
                label: 'Done',
                icon: Symbols.check,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(_resetForm);
  }

  void _resetForm() {
    _photos.clear();
    _condition = null;
    _gender = null;
    _ageRange = null;
    _editingLocation = false;
    _notesCtrl.clear();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
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
            Expanded(
              child: _ready ? _buildForm(context) : const _UoShimmer(),
            ),
            if (_ready) _buildBottomBar(context, online),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final sections = <Widget>[
      // 0 — Header.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Observation',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Log details of a found or at-risk person.',
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const AiModeChip(dense: true),
        ],
      ),
      // 1 — Photos.
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Photos', icon: Symbols.photo_camera),
          _buildPhotoGrid(context),
        ],
      ),
      // 2 — Condition.
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Condition', icon: Symbols.monitor_heart),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in _UoCondition.values)
                _UoConditionChip(
                  condition: c,
                  selected: _condition == c,
                  onTap: () => setState(() => _condition = c),
                ),
            ],
          ),
        ],
      ),
      // 3 — Location.
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Location', icon: Symbols.my_location),
          _buildLocationCard(context),
        ],
      ),
      // 4 — Person details.
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Person details', icon: Symbols.person_search),
          Text(
            'Gender',
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final g in _genders)
                _UoQuickChip(
                  label: g,
                  selected: _gender == g,
                  onTap: () =>
                      setState(() => _gender = _gender == g ? null : g),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Approximate age',
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final a in _ageRanges)
                _UoQuickChip(
                  label: a,
                  selected: _ageRange == a,
                  onTap: () =>
                      setState(() => _ageRange = _ageRange == a ? null : a),
                ),
            ],
          ),
        ],
      ),
      // 5 — Notes.
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Notes', icon: Symbols.edit_note),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              filled: true,
              fillColor: scheme.surface,
              hintText:
                  'Clothing, identifiers, behaviour… e.g. saffron shawl, rudraksha mala, asking for “Ramkund”.',
              hintStyle:
                  text.bodyMedium?.copyWith(color: AppColors.inkFaint),
              contentPadding: const EdgeInsets.all(AppSpacing.base),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++)
            sections[i]
                .animate()
                .fadeIn(duration: 240.ms, delay: (i * 50).ms)
                .slideY(begin: 0.06),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: i < _photos.length
                  ? _UoPhotoTile(
                      file: _photos[i],
                      index: i,
                      onRemove: () => _removePhoto(i),
                    )
                  : i == _photos.length
                      ? _UoAddPhotoTile(
                          count: _photos.length,
                          onTap: _addPhoto,
                        )
                      : const _UoEmptySlotTile(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      accentColor: AppColors.primary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Icon(Symbols.my_location,
                fill: 1, size: 22, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AUTO-DETECTED',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                if (_editingLocation)
                  TextField(
                    controller: _locationCtrl,
                    autofocus: true,
                    style:
                        text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onSubmitted: (_) =>
                        setState(() => _editingLocation = false),
                  )
                else
                  Text(
                    _locationCtrl.text,
                    style:
                        text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 2),
                Text(
                  'GPS · ±8 m accuracy',
                  style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _editingLocation ? 'Save location' : 'Edit location',
            onPressed: () =>
                setState(() => _editingLocation = !_editingLocation),
            icon: Icon(
              _editingLocation ? Symbols.check : Symbols.edit,
              size: 20,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool online) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: AppShadows.raised,
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryCta(
            label: 'Submit Observation',
            icon: Symbols.send,
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          if (!online) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.cloud_off,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 6),
                Text(
                  'Offline — report will be queued and synced automatically',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton — mirrors the final form layout.
// ---------------------------------------------------------------------------
class _UoShimmer extends StatelessWidget {
  const _UoShimmer();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 220, height: 26),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(width: 280, height: 14),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm + 2),
                const Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ShimmerBox(
                      height: double.infinity,
                      radius: AppRadius.input,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ShimmerBox(width: 140, height: 16),
          const SizedBox(height: AppSpacing.md),
          const ShimmerBox(height: 44, radius: AppRadius.pill),
          const SizedBox(height: AppSpacing.xl),
          const ShimmerBox(height: 84, radius: AppRadius.card),
          const SizedBox(height: AppSpacing.xl),
          const ShimmerBox(height: 110, radius: AppRadius.card),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo grid tiles.
// ---------------------------------------------------------------------------
class _UoPhotoTile extends StatelessWidget {
  const _UoPhotoTile({
    required this.file,
    required this.index,
    required this.onRemove,
  });

  final XFile file;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(file.path), fit: BoxFit.cover),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: AppColors.primaryDeep.withValues(alpha: 0.65),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Symbols.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryDeep.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'Photo ${index + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UoAddPhotoTile extends StatelessWidget {
  const _UoAddPhotoTile({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomPaint(
      painter: const _UoDashedBorderPainter(color: AppColors.outline),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.add_a_photo,
                    size: 20, color: AppColors.onPrimaryContainer),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add photo',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '$count/3',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UoEmptySlotTile extends StatelessWidget {
  const _UoEmptySlotTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Icon(
        Symbols.image,
        size: 22,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class _UoDashedBorderPainter extends CustomPainter {
  const _UoDashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(AppRadius.input),
      ));

    const dashWidth = 6.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UoDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Condition segmented chip.
// ---------------------------------------------------------------------------
class _UoConditionChip extends StatelessWidget {
  const _UoConditionChip({
    required this.condition,
    required this.selected,
    required this.onTap,
  });

  final _UoCondition condition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? condition.color : scheme.onSurfaceVariant;

    return Material(
      color: selected ? condition.container : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(
              color: selected ? condition.color : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(condition.icon, size: 18, fill: selected ? 1 : 0, color: fg),
              const SizedBox(width: 6),
              Text(
                condition.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Symbols.check_circle, size: 16, fill: 1, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-select tonal chip (gender / age).
// ---------------------------------------------------------------------------
class _UoQuickChip extends StatelessWidget {
  const _UoQuickChip({
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
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.45)
                  : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

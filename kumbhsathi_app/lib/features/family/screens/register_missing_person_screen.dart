import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';

/// Report Missing Person — premium 4-step wizard (DESIGN.md §6.1).
/// Person → Description → Last seen → Review. Face is embedded and enrolled
/// fully on-device; the case is queued for sync so the flow works offline.
class RegisterMissingPersonScreen extends ConsumerStatefulWidget {
  const RegisterMissingPersonScreen({super.key});

  @override
  ConsumerState<RegisterMissingPersonScreen> createState() =>
      _RegisterMissingPersonScreenState();
}

enum _RegFaceState { none, analyzing, captured, noFace, unavailable }

class _RegisterMissingPersonScreenState
    extends ConsumerState<RegisterMissingPersonScreen> {
  static const List<String> _stepTitles = [
    'Person',
    'Description',
    'Last seen',
    'Review',
  ];

  static const Map<String, String> _ageBands = {
    '0-12': '0–12 years · Child',
    '13-17': '13–17 years · Teen',
    '18-40': '18–40 years · Adult',
    '41-60': '41–60 years · Middle-aged',
    '60+': '60+ years · Senior',
  };

  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _clothingCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();

  int _step = 0;
  String _gender = 'Male';
  String? _ageBand;
  DateTime _lastSeenAt = DateTime.now();
  String? _photoPath;
  List<double>? _embedding;
  _RegFaceState _faceState = _RegFaceState.none;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _clothingCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // Flow helpers
  // ============================================================
  bool get _canContinue => switch (_step) {
        0 => _nameCtrl.text.trim().isNotEmpty && _ageBand != null,
        2 => _locationCtrl.text.trim().isNotEmpty,
        _ => true,
      };

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _resetAll() {
    _nameCtrl.clear();
    _descCtrl.clear();
    _clothingCtrl.clear();
    _locationCtrl.clear();
    _step = 0;
    _gender = 'Male';
    _ageBand = null;
    _lastSeenAt = DateTime.now();
    _photoPath = null;
    _embedding = null;
    _faceState = _RegFaceState.none;
    _submitting = false;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // Photo + on-device face embedding
  // ============================================================
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1280);
      if (picked == null || !mounted) return;
      setState(() {
        _photoPath = picked.path;
        _embedding = null;
        _faceState = _RegFaceState.analyzing;
      });
      await _analyzeFace(picked.path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _faceState =
            _photoPath == null ? _RegFaceState.none : _RegFaceState.unavailable;
      });
      _snack('Could not open the camera. You can continue without a photo.');
    }
  }

  Future<void> _analyzeFace(String path) async {
    try {
      final embedding =
          await ref.read(faceServiceProvider).embedImageFile(path);
      if (!mounted) return;
      setState(() {
        _embedding = embedding;
        _faceState =
            embedding == null ? _RegFaceState.noFace : _RegFaceState.captured;
      });
    } catch (_) {
      // Model missing or inference failure — never blocks the report.
      if (!mounted) return;
      setState(() => _faceState = _RegFaceState.unavailable);
    }
  }

  // ============================================================
  // Date / time pickers
  // ============================================================
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastSeenAt.isAfter(now) ? now : _lastSeenAt,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lastSeenAt = DateTime(picked.year, picked.month, picked.day,
          _lastSeenAt.hour, _lastSeenAt.minute);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_lastSeenAt),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lastSeenAt = DateTime(_lastSeenAt.year, _lastSeenAt.month,
          _lastSeenAt.day, picked.hour, picked.minute);
    });
  }

  // ============================================================
  // Submit — enroll face offline + queue the case for sync
  // ============================================================
  Future<void> _submit() async {
    setState(() => _submitting = true);
    final now = DateTime.now();
    final caseId =
        'KMP-2027-${(now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';
    final name = _nameCtrl.text.trim();

    if (_embedding != null) {
      try {
        await ref.read(faceServiceProvider).enroll(
          caseId: caseId,
          name: name,
          embedding: _embedding!,
          photoPath: _photoPath,
          meta: {
            'gender': _gender,
            'age_band': _ageBand,
            'clothing': _clothingCtrl.text.trim(),
          },
        );
      } catch (_) {
        // Enrollment is best-effort; the case still gets filed.
      }
    }

    try {
      await ref.read(hiveServiceProvider).queueRequest(
        path: '/api/v1/cases',
        method: 'POST',
        body: {
          'case_id': caseId,
          'person_name': name,
          'gender': _gender,
          'age_band': _ageBand,
          'description': _descCtrl.text.trim(),
          'clothing': _clothingCtrl.text.trim(),
          'last_seen_location': _locationCtrl.text.trim(),
          'last_seen_time': _lastSeenAt.toIso8601String(),
          'photo_path': _photoPath,
          'face_enrolled': _embedding != null,
          'reported_at': now.toIso8601String(),
          'source': 'family_app_wizard',
        },
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSuccessSheet(caseId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showErrorSheet();
    }
  }

  void _showSuccessSheet(String caseId) {
    final online = ref.read(isOnlineProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (sheetCtx) => _RegSuccessSheet(
        caseId: caseId,
        online: online,
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: caseId));
          if (!sheetCtx.mounted) return;
          ScaffoldMessenger.of(sheetCtx).showSnackBar(
            const SnackBar(
              content: Text('Case ID copied'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onDone: () async {
          Navigator.of(sheetCtx).pop();
          final popped = await Navigator.of(context).maybePop();
          if (!popped && mounted) setState(_resetAll);
        },
      ),
    );
  }

  void _showErrorSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: EmptyState(
          icon: Symbols.cloud_off,
          color: AppColors.danger,
          title: 'Could not save the report',
          subtitle:
              'Something went wrong while saving locally. Your details are still on this screen — please try again.',
          actionLabel: 'Try again',
          onAction: () {
            Navigator.of(sheetCtx).pop();
            _submit();
          },
        ),
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Report Missing Person'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                  AppSpacing.md, AppSpacing.base, AppSpacing.xs),
              child: Column(
                children: [
                  _RegStepRail(
                    current: _step,
                    onStepTap: (i) => setState(() => _step = i),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'STEP ${_step + 1} OF 4 · ${_stepTitles[_step].toUpperCase()}',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.enter,
                switchInCurve: AppMotion.easeOut,
                switchOutCurve: AppMotion.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey<int>(_step),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                        AppSpacing.sm, AppSpacing.base, AppSpacing.xl),
                    child: switch (_step) {
                      0 => _buildPersonStep(scheme, text),
                      1 => _buildDescriptionStep(scheme, text),
                      2 => _buildLastSeenStep(scheme, text),
                      _ => _buildReviewStep(scheme, text),
                    },
                  ),
                ),
              ),
            ),
            _buildBottomBar(scheme),
          ],
        ),
      ),
    );
  }

  // ---------------- Step 1 — Person ----------------
  Widget _buildPersonStep(ColorScheme scheme, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPhotoCard(scheme, text)
            .animate()
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Full name', required: true),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Name of the missing person',
                prefixIcon: Icon(Symbols.person, size: 22),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _fieldLabel('Gender'),
            const SizedBox(height: AppSpacing.sm),
            _buildGenderSelector(scheme, text),
            const SizedBox(height: AppSpacing.lg),
            _fieldLabel('Estimated age', required: true),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _ageBand,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Select an age range',
                prefixIcon: Icon(Symbols.cake, size: 22),
              ),
              icon: const Icon(Symbols.arrow_drop_down),
              items: [
                for (final entry in _ageBands.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) => setState(() => _ageBand = v),
            ),
          ],
        )
            .animate(delay: 50.ms)
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
      ],
    );
  }

  Widget _buildPhotoCard(ColorScheme scheme, TextTheme text) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_photoPath == null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Symbols.add_a_photo,
                        size: 28, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Add a photo',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'A clear, front-facing photo enables instant\noffline face matching by volunteers.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _RegPhotoButton(
                    icon: Symbols.photo_camera,
                    label: 'Camera',
                    filled: true,
                    onTap: () => _pickPhoto(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _RegPhotoButton(
                    icon: Symbols.photo_library,
                    label: 'Gallery',
                    filled: false,
                    onTap: () => _pickPhoto(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Image.file(
                File(_photoPath!),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _buildFaceChip()),
                TextButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Symbols.refresh, size: 18),
                  label: const Text('Retake'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaceChip() {
    return switch (_faceState) {
      _RegFaceState.none => const SizedBox.shrink(),
      _RegFaceState.analyzing =>
        const ShimmerBox(width: 170, height: 30, radius: AppRadius.pill),
      _RegFaceState.captured => const _RegTonalChip(
          icon: Symbols.check_circle,
          label: 'Face captured ✓',
          fg: AppColors.success,
          bg: AppColors.successContainer,
        ),
      _RegFaceState.noFace => const _RegTonalChip(
          icon: Symbols.visibility_off,
          label: 'No face detected — you can continue',
          fg: AppColors.warning,
          bg: AppColors.warningContainer,
        ),
      _RegFaceState.unavailable => const _RegTonalChip(
          icon: Symbols.offline_bolt,
          label: 'Face AI unavailable — photo saved',
          fg: AppColors.warning,
          bg: AppColors.warningContainer,
        ),
    };
  }

  Widget _buildGenderSelector(ColorScheme scheme, TextTheme text) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          for (final g in const ['Male', 'Female', 'Other'])
            Expanded(
              child: _RegSegment(
                label: g,
                selected: _gender == g,
                onTap: () => setState(() => _gender = g),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- Step 2 — Description ----------------
  Widget _buildDescriptionStep(ColorScheme scheme, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Physical description'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Height, build, complexion, identifying marks, spectacles…',
              ),
            ),
          ],
        ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Clothing when last seen'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _clothingCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. saffron kurta, grey shawl, black slippers',
                prefixIcon: Icon(Symbols.apparel, size: 22),
              ),
            ),
          ],
        )
            .animate(delay: 50.ms)
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          color: AppColors.infoContainer,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Symbols.tips_and_updates,
                  size: 20, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Small details help most — a limp, a tattoo, a tilak, or the colour of a bag.',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate(delay: 100.ms)
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
      ],
    );
  }

  // ---------------- Step 3 — Last seen ----------------
  Widget _buildLastSeenStep(ColorScheme scheme, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Last seen location', required: true),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _locationCtrl,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'e.g. Sector 12, near Hanuman Mandir gate',
                prefixIcon: Icon(Symbols.location_on, size: 22),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Last seen time', required: true),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _RegPickerTile(
                    icon: Symbols.calendar_month,
                    label: DateFormat('EEE, d MMM yyyy').format(_lastSeenAt),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _RegPickerTile(
                    icon: Symbols.schedule,
                    label: DateFormat('h:mm a').format(_lastSeenAt),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (label, minutes) in const <(String, int)>[
                  ('Just now', 0),
                  ('30 min ago', 30),
                  ('1 hr ago', 60),
                  ('3 hrs ago', 180),
                ])
                  _RegTimeChip(
                    label: label,
                    onTap: () => setState(() {
                      _lastSeenAt =
                          DateTime.now().subtract(Duration(minutes: minutes));
                    }),
                  ),
              ],
            ),
          ],
        )
            .animate(delay: 50.ms)
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
      ],
    );
  }

  // ---------------- Step 4 — Review ----------------
  Widget _buildReviewStep(ColorScheme scheme, TextTheme text) {
    final name =
        _nameCtrl.text.trim().isEmpty ? 'Unknown' : _nameCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RegReviewCard(
          title: 'Person',
          onEdit: () => setState(() => _step = 0),
          child: Row(
            children: [
              if (_photoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: Image.file(
                    File(_photoPath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                )
              else
                PersonAvatar(name, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '$_gender · ${_ageBands[_ageBand] ?? 'Age unknown'}',
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _RegTonalChip(
                      icon: _embedding != null
                          ? Symbols.face_retouching_natural
                          : Symbols.face_retouching_off,
                      label: _embedding != null
                          ? 'Face ID ready — offline matching enabled'
                          : 'No face ID — matching by description',
                      fg: _embedding != null
                          ? AppColors.success
                          : AppColors.warning,
                      bg: _embedding != null
                          ? AppColors.successContainer
                          : AppColors.warningContainer,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.md),
        _RegReviewCard(
          title: 'Description',
          onEdit: () => setState(() => _step = 1),
          child: Column(
            children: [
              _RegSummaryRow(
                icon: Symbols.description,
                label: 'Appearance',
                value: _descCtrl.text.trim().isEmpty
                    ? '—'
                    : _descCtrl.text.trim(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _RegSummaryRow(
                icon: Symbols.apparel,
                label: 'Clothing',
                value: _clothingCtrl.text.trim().isEmpty
                    ? '—'
                    : _clothingCtrl.text.trim(),
              ),
            ],
          ),
        )
            .animate(delay: 50.ms)
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.md),
        _RegReviewCard(
          title: 'Last seen',
          onEdit: () => setState(() => _step = 2),
          child: Column(
            children: [
              _RegSummaryRow(
                icon: Symbols.location_on,
                label: 'Location',
                value: _locationCtrl.text.trim().isEmpty
                    ? '—'
                    : _locationCtrl.text.trim(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _RegSummaryRow(
                icon: Symbols.schedule,
                label: 'Time',
                value: DateFormat('EEE, d MMM yyyy · h:mm a')
                    .format(_lastSeenAt),
              ),
            ],
          ),
        )
            .animate(delay: 100.ms)
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: AppColors.successContainer,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Symbols.cloud_sync, size: 20, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'This report is saved on your phone and syncs to the control room automatically — even if you are offline right now.',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.onSuccessContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate(delay: 150.ms)
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
      ],
    );
  }

  // ---------------- Shared bits ----------------
  Widget _fieldLabel(String label, {bool required = false}) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        text: label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: AppShadows.raised,
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.md),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              flex: 2,
              child: PrimaryCta.tonal(
                label: 'Back',
                onPressed: _submitting ? null : _back,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            flex: 3,
            child: PrimaryCta(
              label: _step == 3 ? 'Submit report' : 'Continue',
              icon: _step == 3 ? Symbols.send : Symbols.arrow_forward,
              loading: _submitting,
              onPressed: _canContinue ? _next : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Step pill rail
// ============================================================
class _RegStepRail extends StatelessWidget {
  const _RegStepRail({required this.current, required this.onStepTap});

  final int current;
  final ValueChanged<int> onStepTap;

  static const List<String> _labels = [
    'Person',
    'Description',
    'Last seen',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.enter,
                curve: AppMotion.easeOut,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: i <= current ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          _buildPill(i, scheme, text),
        ],
      ],
    );
  }

  Widget _buildPill(int i, ColorScheme scheme, TextTheme text) {
    final done = i < current;
    final active = i == current;
    final bg = done
        ? scheme.primaryContainer
        : active
            ? scheme.primary
            : scheme.surfaceContainerHigh;
    return GestureDetector(
      onTap: i <= current ? () => onStepTap(i) : null,
      child: AnimatedContainer(
        duration: AppMotion.enter,
        curve: AppMotion.easeOut,
        height: 32,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: active ? AppSpacing.md : 0),
        constraints: const BoxConstraints(minWidth: 32),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: done || active
              ? null
              : Border.all(color: scheme.outlineVariant),
        ),
        child: AnimatedSize(
          duration: AppMotion.enter,
          curve: AppMotion.easeOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (done)
                Icon(Symbols.check, size: 16, color: scheme.onPrimaryContainer)
              else
                Text(
                  '${i + 1}',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
              if (active) ...[
                const SizedBox(width: 6),
                Text(
                  _labels[i],
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Small private widgets
// ============================================================
class _RegTonalChip extends StatelessWidget {
  const _RegTonalChip({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm - 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegPhotoButton extends StatelessWidget {
  const _RegPhotoButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = filled ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final fg = filled ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.button),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
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

class _RegSegment extends StatelessWidget {
  const _RegSegment({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.exit,
        curve: AppMotion.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          boxShadow: selected ? AppShadows.card : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _RegPickerTile extends StatelessWidget {
  const _RegPickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegTimeChip extends StatelessWidget {
  const _RegTimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _RegSummaryRow extends StatelessWidget {
  const _RegSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _RegReviewCard extends StatelessWidget {
  const _RegReviewCard({
    required this.title,
    required this.onEdit,
    required this.child,
  });

  final String title;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      accentColor: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Symbols.edit, size: 15),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

// ============================================================
// Success bottom sheet
// ============================================================
class _RegSuccessSheet extends StatelessWidget {
  const _RegSuccessSheet({
    required this.caseId,
    required this.online,
    required this.onCopy,
    required this.onDone,
  });

  final String caseId;
  final bool online;
  final VoidCallback onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.successContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.check_circle,
                  size: 36, color: AppColors.success),
            )
                .animate()
                .fadeIn(duration: 240.ms)
                .scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: AppSpacing.base),
            Text(
              'Report submitted',
              style:
                  text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Search teams are being alerted. Keep this case ID safe:',
              textAlign: TextAlign.center,
              style:
                  text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.base),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caseId,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    onPressed: onCopy,
                    icon: const Icon(Symbols.content_copy, size: 18),
                    tooltip: 'Copy case ID',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Icon(Symbols.location_searching,
                        size: 20, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Track progress anytime from the Track Case tab using this case ID.',
                      style: text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  online ? Symbols.cloud_done : Symbols.cloud_off,
                  size: 16,
                  color: online ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  online
                      ? 'Syncing to the control room'
                      : 'Saved offline — will sync automatically',
                  style: text.labelMedium?.copyWith(
                    color: online ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryCta(label: 'Done', icon: Symbols.check, onPressed: onDone),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../services/face/face_recognition_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../settings/screens/ai_settings_screen.dart';

/// Volunteer "Found person" face scan (DESIGN.md §6.3 + §7.1).
///
/// Hero instruction card → big dashed capture zone → on-device
/// MobileFaceNet pipeline → top-3 matches in a bottom sheet with
/// confidence rings → Confirm queues `/api/v1/face/confirm` offline and
/// shows a full-screen success state ("Family and police notified").
class FoundPersonFaceScanScreen extends ConsumerStatefulWidget {
  const FoundPersonFaceScanScreen({super.key});

  @override
  ConsumerState<FoundPersonFaceScanScreen> createState() =>
      _FoundPersonFaceScanScreenState();
}

enum _FpfsPhase {
  idle,
  scanning,
  noFace,
  noMatches,
  modelMissing,
  error,
  success,
}

class _FoundPersonFaceScanScreenState
    extends ConsumerState<FoundPersonFaceScanScreen> {
  final ImagePicker _picker = ImagePicker();

  _FpfsPhase _phase = _FpfsPhase.idle;
  String? _photoPath;
  String? _errorMessage;
  FaceMatchCandidate? _confirmed;

  // ============================================================
  // Pipeline: capture → embed → match → sheet
  // ============================================================
  Future<void> _capture(ImageSource source) async {
    if (_phase == _FpfsPhase.scanning) return;
    XFile? file;
    try {
      file = await _picker.pickImage(source: source, maxWidth: 1280);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open camera: $e')),
      );
      return;
    }
    if (file == null || !mounted) return;
    final path = file.path;
    setState(() {
      _photoPath = path;
      _phase = _FpfsPhase.scanning;
      _errorMessage = null;
    });

    final face = ref.read(faceServiceProvider);
    if (face.status == FaceServiceStatus.modelMissing ||
        face.status == FaceServiceStatus.downloading) {
      setState(() => _phase = _FpfsPhase.modelMissing);
      return;
    }
    try {
      final embedding = await face.embedImageFile(path);
      if (!mounted) return;
      if (embedding == null) {
        setState(() => _phase = _FpfsPhase.noFace);
        return;
      }
      final matches = await face.match(embedding, topK: 3, threshold: 0.45);
      if (!mounted) return;
      if (matches.isEmpty) {
        setState(() => _phase = _FpfsPhase.noMatches);
        return;
      }
      setState(() => _phase = _FpfsPhase.idle);
      await _showResultsSheet(matches, path);
    } on StateError {
      if (mounted) setState(() => _phase = _FpfsPhase.modelMissing);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _phase = _FpfsPhase.error;
      });
    }
  }

  Future<void> _showResultsSheet(
      List<FaceMatchCandidate> matches, String queryPath) async {
    final chosen = await showModalBottomSheet<FaceMatchCandidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FpfsResultsSheet(matches: matches, queryPath: queryPath),
    );
    if (chosen != null && mounted) await _confirmMatch(chosen);
  }

  Future<void> _confirmMatch(FaceMatchCandidate candidate) async {
    final user = ref.read(authStateProvider).user;
    try {
      await ref.read(hiveServiceProvider).queueRequest(
        path: '/api/v1/face/confirm',
        method: 'POST',
        body: {
          'case_id': candidate.caseId,
          'matched_name': candidate.name,
          'confidence': double.parse(candidate.score.toStringAsFixed(4)),
          'band': _fpfsBandLabel(candidate.score),
          'source': 'volunteer_found_person_scan',
          'confirmed_by': user?.id,
          'confirmed_by_role': user?.role.name ?? 'volunteer',
          'confirmed_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save confirmation: $e')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Match confirmed — will sync when back online')),
    );
    setState(() {
      _confirmed = candidate;
      _phase = _FpfsPhase.success;
    });
  }

  void _reset() {
    setState(() {
      _phase = _FpfsPhase.idle;
      _photoPath = null;
      _errorMessage = null;
      _confirmed = null;
    });
  }

  void _openAiSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()),
    );
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final confirmed = _confirmed;
    final Widget content;
    if (_phase == _FpfsPhase.success && confirmed != null) {
      content = _FpfsSuccessView(
        candidate: confirmed,
        onDone: () => Navigator.of(context).maybePop(),
        onScanAgain: _reset,
      );
    } else {
      content = _buildScanBody();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Found Person'),
        actions: const [
          AiModeChip(dense: true),
          SizedBox(width: AppSpacing.base),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildScanBody() {
    final face = ref.watch(faceServiceProvider);
    final scanning = _phase == _FpfsPhase.scanning;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        _FpfsHeroCard(enrolledCount: face.enrolledCount)
            .animate()
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.base),
        _FpfsCaptureZone(
          imagePath: _photoPath,
          scanning: scanning,
          onTap: scanning ? null : () => _capture(ImageSource.camera),
        )
            .animate(delay: 50.ms)
            .fadeIn(duration: 240.ms)
            .slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.base),
        PrimaryCta(
          label: _photoPath == null ? 'Capture Photo' : 'Scan Again',
          icon: Symbols.photo_camera,
          loading: scanning,
          onPressed: scanning ? null : () => _capture(ImageSource.camera),
        ).animate(delay: 100.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.sm),
        PrimaryCta.tonal(
          label: 'Choose from gallery',
          icon: Symbols.photo_library,
          onPressed: scanning ? null : () => _capture(ImageSource.gallery),
        ).animate(delay: 150.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06),
        const SizedBox(height: AppSpacing.base),
        ..._buildPhaseSection(),
      ],
    );
  }

  List<Widget> _buildPhaseSection() {
    switch (_phase) {
      case _FpfsPhase.scanning:
        return [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Matching against local index…',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < 3; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ShimmerBox(height: 64, radius: AppRadius.card),
                  ),
              ],
            ),
          ),
        ];
      case _FpfsPhase.modelMissing:
        return [
          AppCard(
            child: EmptyState(
              icon: Symbols.deployed_code_update,
              title: 'Face model not installed',
              subtitle:
                  'Download the on-device face model once to scan and match '
                  'found persons fully offline.',
              actionLabel: 'Open AI Settings',
              onAction: _openAiSettings,
            ),
          ),
        ];
      case _FpfsPhase.noFace:
        return [
          AppCard(
            child: EmptyState(
              icon: Symbols.face_retouching_off,
              title: 'No face detected',
              subtitle:
                  'Hold the camera steady, fill the frame with the face and '
                  'avoid strong backlight, then try again.',
              actionLabel: 'Retake photo',
              onAction: () => _capture(ImageSource.camera),
              color: AppColors.warning,
            ),
          ),
        ];
      case _FpfsPhase.noMatches:
        return [
          AppCard(
            child: EmptyState(
              icon: Symbols.person_search,
              title: 'No match found',
              subtitle:
                  'No enrolled missing-person case scored above 45% on this '
                  'device. Report an observation so police can follow up.',
              actionLabel: 'Scan again',
              onAction: () => _capture(ImageSource.camera),
            ),
          ),
        ];
      case _FpfsPhase.error:
        return [
          AppCard(
            child: EmptyState(
              icon: Symbols.error,
              title: 'Scan failed',
              subtitle: _errorMessage ?? 'Something went wrong on-device.',
              actionLabel: 'Try again',
              onAction: () => _capture(ImageSource.camera),
              color: AppColors.danger,
            ),
          ),
        ];
      case _FpfsPhase.idle:
      case _FpfsPhase.success:
        return [
          const _FpfsTipsCard()
              .animate(delay: 200.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
        ];
    }
  }
}

// ============================================================
// Confidence bands (≥0.75 strong / ≥0.60 probable / weak)
// ============================================================
Color _fpfsBandColor(double score) => score >= 0.75
    ? AppColors.success
    : score >= 0.6
        ? AppColors.warning
        : AppColors.danger;

String _fpfsBandLabel(double score) =>
    score >= 0.75 ? 'Strong' : score >= 0.6 ? 'Probable' : 'Weak';

// ============================================================
// Pieces
// ============================================================

/// Hero instruction card on the brand gradient.
class _FpfsHeroCard extends StatelessWidget {
  const _FpfsHeroCard({required this.enrolledCount});

  final int enrolledCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: const Icon(Symbols.familiar_face_and_zone,
                    size: 26, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan the found person',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Take a clear, front-facing photo. Matching runs on '
                      'this phone against enrolled missing-person cases.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              const _FpfsHeroChip(
                icon: Symbols.wifi_off,
                label: 'Works fully offline',
              ),
              _FpfsHeroChip(
                icon: Symbols.database,
                label: '$enrolledCount faces in local index',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FpfsHeroChip extends StatelessWidget {
  const _FpfsHeroChip({required this.icon, required this.label});

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
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}

/// Big dashed capture zone; tap to open the camera, previews the photo.
class _FpfsCaptureZone extends StatelessWidget {
  const _FpfsCaptureZone({
    required this.imagePath,
    required this.scanning,
    this.onTap,
  });

  final String? imagePath;
  final bool scanning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = imagePath;
    return Semantics(
      button: true,
      label: 'Capture photo of found person',
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: _FpfsDashedBorderPainter(
            color: path == null ? AppColors.outline : AppColors.primary,
            radius: AppRadius.sheet,
          ),
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.sheet),
            ),
            clipBehavior: Clip.antiAlias,
            child: path == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Symbols.photo_camera,
                            size: 36, color: AppColors.primary),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Text(
                        'Tap to capture',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Center the face in good light',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(path), fit: BoxFit.cover),
                      if (scanning)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x66000000),
                            child: Center(
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FpfsDashedBorderPainter extends CustomPainter {
  _FpfsDashedBorderPainter({required this.color, required this.radius});

  static const double _dash = 8;
  static const double _gap = 6;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.8),
        Radius.circular(radius),
      ));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FpfsDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Radial confidence ring with tabular percent label.
class _FpfsConfidenceRing extends StatelessWidget {
  const _FpfsConfidenceRing(this.score, {this.size = 52});

  static const double _stroke = 5;

  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _fpfsBandColor(score);
    final pct = (score * 100).clamp(0, 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score.clamp(0.0, 1.0),
            strokeWidth: _stroke,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          Center(
            child: Text(
              '$pct%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.25,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: top-3 candidates, selectable rows, Confirm CTA.
/// Pops with the chosen [FaceMatchCandidate] on confirm, null on dismiss.
class _FpfsResultsSheet extends StatefulWidget {
  const _FpfsResultsSheet({required this.matches, required this.queryPath});

  final List<FaceMatchCandidate> matches;
  final String queryPath;

  @override
  State<_FpfsResultsSheet> createState() => _FpfsResultsSheetState();
}

class _FpfsResultsSheetState extends State<_FpfsResultsSheet> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = widget.matches[_selected];
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.xl),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              'Possible matches',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Top ${widget.matches.length} from the on-device index. '
              'Select the correct person and confirm.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.base),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < widget.matches.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _FpfsMatchRow(
                          candidate: widget.matches[i],
                          rank: i + 1,
                          selected: i == _selected,
                          onTap: () => setState(() => _selected = i),
                        )
                            .animate(delay: ((i < 6 ? i : 5) * 50).ms)
                            .fadeIn(duration: 240.ms)
                            .slideY(begin: 0.06),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryCta(
              label: 'Confirm Match — ${_fpfsBandLabel(chosen.score)}',
              icon: Symbols.verified_user,
              onPressed: () => Navigator.of(context).pop(chosen),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('None of these — scan again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FpfsMatchRow extends StatelessWidget {
  const _FpfsMatchRow({
    required this.candidate,
    required this.rank,
    required this.selected,
    required this.onTap,
  });

  final FaceMatchCandidate candidate;
  final int rank;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final band = _fpfsBandColor(candidate.score);
    return AnimatedContainer(
      duration: AppMotion.exit,
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                PersonAvatar(candidate.name, size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        candidate.caseId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.inkFaint,
                          letterSpacing: 0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '#$rank · ${_fpfsBandLabel(candidate.score)} match',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: band,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _FpfsConfidenceRing(candidate.score),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen success state: success tonal wash, check disc,
/// "Family and police notified", plus the confirmed case card.
class _FpfsSuccessView extends StatelessWidget {
  const _FpfsSuccessView({
    required this.candidate,
    required this.onDone,
    required this.onScanAgain,
  });

  final FaceMatchCandidate candidate;
  final VoidCallback onDone;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: AppColors.successContainer,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: const Icon(Symbols.check_circle,
                    size: 56, color: AppColors.success, fill: 1),
              )
                  .animate()
                  .fadeIn(duration: 240.ms)
                  .scale(
                      begin: const Offset(0.8, 0.8),
                      curve: Curves.easeOutCubic),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Match Confirmed',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.onSuccessContainer,
                fontWeight: FontWeight.w800,
              ),
            ).animate(delay: 50.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Family and police notified. The case timeline has been '
              'updated — everything syncs automatically when online.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: AppColors.onSuccessContainer),
            )
                .animate(delay: 100.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Row(
                children: [
                  PersonAvatar(candidate.name,
                      size: 56, statusDot: AppColors.success),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          candidate.caseId,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.inkFaint,
                            letterSpacing: 0.5,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const StatusBadge.fromLabel('Reunited'),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _FpfsConfidenceRing(candidate.score, size: 56),
                ],
              ),
            )
                .animate(delay: 150.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),
            const SizedBox(height: AppSpacing.xl),
            PrimaryCta(label: 'Done', icon: Symbols.check, onPressed: onDone)
                .animate(delay: 200.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.06),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onScanAgain,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: AppColors.onSuccessContainer,
              ),
              child: const Text('Scan another person'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick guidance card shown before/after a scan.
class _FpfsTipsCard extends StatelessWidget {
  const _FpfsTipsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const tips = [
      (Symbols.light_mode, 'Face the person toward the light'),
      (Symbols.person, 'One face in frame, eyes visible'),
      (Symbols.encrypted, 'Photo stays on this device'),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tips for a good scan',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (icon, label) in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
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

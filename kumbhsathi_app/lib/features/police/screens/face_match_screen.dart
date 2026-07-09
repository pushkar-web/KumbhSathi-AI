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
import '../../../shared/widgets/section_header.dart';
import '../../settings/screens/ai_settings_screen.dart';

/// Offline face match console for police (DESIGN.md §6.2).
///
/// Left: sticky query card with a dashed capture/upload zone.
/// Right: shimmer → top-5 candidates from the local MobileFaceNet index,
/// each with a confidence ring; tap → side-by-side compare sheet → confirm
/// (queued offline via [hiveServiceProvider]).
class FaceMatchScreen extends ConsumerStatefulWidget {
  const FaceMatchScreen({super.key});

  @override
  ConsumerState<FaceMatchScreen> createState() => _FaceMatchScreenState();
}

enum _FmPhase { idle, scanning, noFace, modelMissing, error, results }

class _FaceMatchScreenState extends ConsumerState<FaceMatchScreen> {
  final ImagePicker _picker = ImagePicker();

  _FmPhase _phase = _FmPhase.idle;
  String? _queryPath;
  List<FaceMatchCandidate> _matches = const [];
  String? _errorMessage;

  // ============================================================
  // Pipeline: pick → embed → match
  // ============================================================
  Future<void> _pick(ImageSource source) async {
    if (_phase == _FmPhase.scanning) return;
    XFile? file;
    try {
      file = await _picker.pickImage(source: source, maxWidth: 1280);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open picker: $e')),
      );
      return;
    }
    if (file == null || !mounted) return;
    final path = file.path;
    setState(() {
      _queryPath = path;
      _phase = _FmPhase.scanning;
      _matches = const [];
      _errorMessage = null;
    });
    await _runPipeline(path);
  }

  Future<void> _runPipeline(String path) async {
    final face = ref.read(faceServiceProvider);
    if (face.status == FaceServiceStatus.modelMissing ||
        face.status == FaceServiceStatus.downloading) {
      if (mounted) setState(() => _phase = _FmPhase.modelMissing);
      return;
    }
    try {
      final embedding = await face.embedImageFile(path);
      if (!mounted) return;
      if (embedding == null) {
        setState(() => _phase = _FmPhase.noFace);
        return;
      }
      final matches = await face.match(embedding, topK: 5, threshold: 0.45);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _phase = _FmPhase.results;
      });
    } on StateError {
      if (mounted) setState(() => _phase = _FmPhase.modelMissing);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _phase = _FmPhase.error;
      });
    }
  }

  void _reset() {
    setState(() {
      _phase = _FmPhase.idle;
      _queryPath = null;
      _matches = const [];
      _errorMessage = null;
    });
  }

  void _openAiSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()),
    );
  }

  // ============================================================
  // Compare & confirm
  // ============================================================
  Future<void> _openCompareSheet(FaceMatchCandidate candidate) async {
    final queryPath = _queryPath;
    if (queryPath == null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) =>
          _FmCompareSheet(candidate: candidate, queryPath: queryPath),
    );
    if (confirmed == true && mounted) await _confirmMatch(candidate);
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
          'band': _fmBandLabel(candidate.score),
          'source': 'police_face_match',
          'confirmed_by': user?.id,
          'confirmed_by_role': user?.role.name ?? 'police',
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
      const SnackBar(content: Text('Confirmation saved — will sync when online')),
    );
    await showDialog<void>(
      context: context,
      builder: (_) => _FmSuccessDialog(candidate: candidate),
    );
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final face = ref.watch(faceServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Match'),
        actions: const [
          AiModeChip(),
          SizedBox(width: AppSpacing.base),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 920;
            if (!wide) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.base),
                children: [
                  _buildQueryCard(face)
                      .animate()
                      .fadeIn(duration: 240.ms)
                      .slideY(begin: 0.06),
                  const SizedBox(height: AppSpacing.base),
                  _buildResultsPanel(),
                ],
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sticky query column: scrolls independently, stays put
                    // while the results panel scrolls.
                    SizedBox(
                      width: 400,
                      height: constraints.maxHeight,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                            AppSpacing.xl, AppSpacing.md, AppSpacing.xl),
                        child: _buildQueryCard(face)
                            .animate()
                            .fadeIn(duration: 240.ms)
                            .slideY(begin: 0.06),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                              AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                          child: _buildResultsPanel(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---- Left: query card ----
  Widget _buildQueryCard(FaceRecognitionService face) {
    final theme = Theme.of(context);
    final scanning = _phase == _FmPhase.scanning;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Query face',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _FmIndexChip(count: face.enrolledCount),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Capture or upload a clear, front-facing photo. Matching runs '
            'entirely on this device — no network needed.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.base),
          _FmCaptureZone(
            imagePath: _queryPath,
            scanning: scanning,
            onClear: scanning ? null : _reset,
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed:
                      scanning ? null : () => _pick(ImageSource.camera),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  icon: const Icon(Symbols.photo_camera, size: 20),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      scanning ? null : () => _pick(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  icon: const Icon(Symbols.upload, size: 20),
                  label: const Text('Upload'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              const Icon(Symbols.encrypted,
                  size: 16, color: AppColors.inkFaint),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Photos never leave the device. Threshold 45% similarity.',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.inkFaint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Right: results panel by phase ----
  Widget _buildResultsPanel() {
    switch (_phase) {
      case _FmPhase.idle:
        return const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xxl),
          child: EmptyState(
            icon: Symbols.familiar_face_and_zone,
            title: 'No query yet',
            subtitle:
                'Capture or upload a photo on the left to search the local '
                'face index for matching missing-person cases.',
          ),
        );
      case _FmPhase.scanning:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Analyzing face…'),
            const ShimmerBox(width: 220, height: 14),
            const SizedBox(height: AppSpacing.base),
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: ShimmerBox(height: 112, radius: AppRadius.card),
              ),
          ],
        );
      case _FmPhase.modelMissing:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl),
          child: EmptyState(
            icon: Symbols.deployed_code_update,
            title: 'Face model not installed',
            subtitle:
                'Download the on-device face model once to run fully offline '
                'matching at the mela grounds.',
            actionLabel: 'Open AI Settings',
            onAction: _openAiSettings,
          ),
        );
      case _FmPhase.noFace:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl),
          child: EmptyState(
            icon: Symbols.face_retouching_off,
            title: 'No face detected',
            subtitle:
                'The photo does not contain a recognizable face. Try a '
                'sharper, well-lit, front-facing photo.',
            actionLabel: 'Choose another photo',
            onAction: () => _pick(ImageSource.gallery),
            color: AppColors.warning,
          ),
        );
      case _FmPhase.error:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl),
          child: EmptyState(
            icon: Symbols.error,
            title: 'Face matching failed',
            subtitle: _errorMessage ?? 'Something went wrong on-device.',
            actionLabel: 'Try again',
            onAction: () {
              final p = _queryPath;
              if (p == null) {
                _reset();
                return;
              }
              setState(() => _phase = _FmPhase.scanning);
              _runPipeline(p);
            },
            color: AppColors.danger,
          ),
        );
      case _FmPhase.results:
        if (_matches.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: EmptyState(
              icon: Symbols.person_search,
              title: 'No matches in the local index',
              subtitle:
                  'No enrolled case scored above the 45% similarity '
                  'threshold. Enroll more cases or try another photo.',
              actionLabel: 'Scan another photo',
              onAction: () => _pick(ImageSource.gallery),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Top matches (${_matches.length})',
              icon: Symbols.social_leaderboard,
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                mainAxisExtent: 128,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
              ),
              itemCount: _matches.length,
              itemBuilder: (context, i) {
                final m = _matches[i];
                return _FmMatchCard(
                  candidate: m,
                  rank: i + 1,
                  onTap: () => _openCompareSheet(m),
                )
                    .animate(delay: ((i < 6 ? i : 5) * 50).ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: 0.06);
              },
            ),
          ],
        );
    }
  }
}

// ============================================================
// Confidence bands (assignment spec: ≥0.75 / ≥0.60 / below)
// ============================================================
Color _fmBandColor(double score) => score >= 0.75
    ? AppColors.success
    : score >= 0.6
        ? AppColors.warning
        : AppColors.danger;

Color _fmBandContainer(double score) => score >= 0.75
    ? AppColors.successContainer
    : score >= 0.6
        ? AppColors.warningContainer
        : AppColors.dangerContainer;

String _fmBandLabel(double score) =>
    score >= 0.75 ? 'Strong' : score >= 0.6 ? 'Probable' : 'Weak';

// ============================================================
// Pieces
// ============================================================

/// Tonal pill: "<n> faces in local index".
class _FmIndexChip extends StatelessWidget {
  const _FmIndexChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.database,
              size: 14, color: AppColors.onPrimaryContainer),
          const SizedBox(width: 5),
          Text(
            '$count faces in local index',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}

/// Dashed-border capture/upload well; previews the picked image.
class _FmCaptureZone extends StatelessWidget {
  const _FmCaptureZone({
    required this.imagePath,
    required this.scanning,
    this.onClear,
  });

  final String? imagePath;
  final bool scanning;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = imagePath;
    return CustomPaint(
      foregroundPainter: _FmDashedBorderPainter(
        color: path == null ? AppColors.outline : AppColors.primary,
        radius: AppRadius.card,
      ),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: path == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Symbols.add_a_photo,
                        size: 28, color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Drop a face here',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Use the camera or upload from gallery',
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
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.white),
                          ),
                        ),
                      ),
                    )
                  else if (onClear != null)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          onPressed: onClear,
                          tooltip: 'Clear photo',
                          icon: const Icon(Symbols.close,
                              size: 20, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _FmDashedBorderPainter extends CustomPainter {
  _FmDashedBorderPainter({required this.color, required this.radius});

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
  bool shouldRepaint(covariant _FmDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Radial confidence ring: colored progress arc + tabular percent label.
class _FmConfidenceRing extends StatelessWidget {
  const _FmConfidenceRing(this.score, {this.size = 56, this.stroke = 5});

  final double score;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final color = _fmBandColor(score);
    final pct = (score * 100).clamp(0, 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score.clamp(0.0, 1.0),
            strokeWidth: stroke,
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
                    fontSize: size * 0.24,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One match candidate: avatar, name, case id, band pill + confidence ring.
class _FmMatchCard extends StatelessWidget {
  const _FmMatchCard({
    required this.candidate,
    required this.rank,
    required this.onTap,
  });

  final FaceMatchCandidate candidate;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      accentColor: _fmBandColor(candidate.score),
      child: Row(
        children: [
          PersonAvatar(candidate.name, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _fmBandContainer(candidate.score),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '#$rank · ${_fmBandLabel(candidate.score)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _fmBandColor(candidate.score),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _FmConfidenceRing(candidate.score),
        ],
      ),
    );
  }
}

/// Side-by-side compare sheet; pops `true` when the officer confirms.
class _FmCompareSheet extends StatelessWidget {
  const _FmCompareSheet({required this.candidate, required this.queryPath});

  final FaceMatchCandidate candidate;
  final String queryPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoPath = candidate.photoPath;
    final hasPhoto = photoPath != null && File(photoPath).existsSync();
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
              'Compare & confirm',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${candidate.name} · ${candidate.caseId}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _FmComparePane(
                    label: 'Scanned photo',
                    child: Image.file(File(queryPath), fit: BoxFit.cover),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxl),
                  child: Icon(Symbols.compare_arrows,
                      size: 24, color: AppColors.inkFaint),
                ),
                Expanded(
                  child: _FmComparePane(
                    label: 'Enrolled case',
                    child: hasPhoto
                        ? Image.file(File(photoPath), fit: BoxFit.cover)
                        : Center(child: PersonAvatar(candidate.name, size: 72)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FmConfidenceRing(candidate.score, size: 72, stroke: 6),
                const SizedBox(width: AppSpacing.base),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_fmBandLabel(candidate.score)} match',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _fmBandColor(candidate.score),
                      ),
                    ),
                    Text(
                      'Cosine similarity, on-device',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryCta(
              label: 'Confirm Match',
              icon: Symbols.verified_user,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Not the same person'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FmComparePane extends StatelessWidget {
  const _FmComparePane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          width: double.infinity,
          child: child,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Post-confirmation dialog: timeline updated + notifications queued.
class _FmSuccessDialog extends StatelessWidget {
  const _FmSuccessDialog({required this.candidate});

  final FaceMatchCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.modal)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.successContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.check_circle,
                size: 36, color: AppColors.success, fill: 1),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Match confirmed',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Case ${candidate.caseId} timeline updated. Family and assigned '
            'officers will be notified — syncs automatically when online.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            minimumSize: const Size(140, 44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

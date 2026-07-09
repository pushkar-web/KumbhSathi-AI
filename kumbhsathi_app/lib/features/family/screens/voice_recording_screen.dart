import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/ai_providers.dart';
import '../../../services/ai/ai_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/section_header.dart';

/// Voice Report — premium recorder (DESIGN.md §6.1 "Voice").
/// Records via `package:record`; if the microphone is unavailable the screen
/// degrades to a simulation mode so the demo flow never breaks. On stop, the
/// AI orchestrator structures the report (Groq → Gemma on-device → template).
class VoiceRecordingScreen extends ConsumerStatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  ConsumerState<VoiceRecordingScreen> createState() =>
      _VoiceRecordingScreenState();
}

enum _VoicePhase { idle, recording, transcribing, done, failed }

class _VoiceRecordingScreenState extends ConsumerState<VoiceRecordingScreen>
    with SingleTickerProviderStateMixin {
  static const int _barCount = 36;
  static const double _idleLevel = 0.08;
  static const Duration _maxDuration = Duration(minutes: 3);

  final AudioRecorder _recorder = AudioRecorder();
  final math.Random _rng = math.Random();

  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  )..addStatusListener(_onWaveStatus);

  final List<double> _prevBars =
      List<double>.filled(_barCount, _idleLevel, growable: false);
  final List<double> _nextBars =
      List<double>.filled(_barCount, _idleLevel, growable: false);

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  _VoicePhase _phase = _VoicePhase.idle;
  bool _simulated = false;
  String? _audioPath;
  AiResult? _result;
  String _language = 'हिन्दी';

  @override
  void dispose() {
    _ticker?.cancel();
    _wave.dispose();
    try {
      _recorder.dispose();
    } catch (_) {
      // Recorder may already be released — never crash on exit.
    }
    super.dispose();
  }

  // ============================================================
  // Waveform driver — random bar heights lerped every cycle
  // ============================================================
  void _onWaveStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    var settled = true;
    for (var i = 0; i < _barCount; i++) {
      _prevBars[i] = _nextBars[i];
      _nextBars[i] = _phase == _VoicePhase.recording
          ? 0.15 + _rng.nextDouble() * 0.85
          : _idleLevel;
      if ((_nextBars[i] - _prevBars[i]).abs() > 0.001) settled = false;
    }
    if (!settled || _phase == _VoicePhase.recording) {
      _wave.forward(from: 0);
    }
  }

  void _kickWave() {
    for (var i = 0; i < _barCount; i++) {
      _prevBars[i] = _nextBars[i];
      _nextBars[i] = _phase == _VoicePhase.recording
          ? 0.15 + _rng.nextDouble() * 0.85
          : _idleLevel;
    }
    _wave.forward(from: 0);
  }

  // ============================================================
  // Recording lifecycle
  // ============================================================
  Future<void> _startRecording() async {
    setState(() {
      _phase = _VoicePhase.recording;
      _elapsed = Duration.zero;
      _result = null;
      _simulated = false;
      _audioPath = null;
    });
    try {
      if (!await _recorder.hasPermission()) {
        throw StateError('Microphone permission denied');
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/ks_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _audioPath = path;
    } catch (_) {
      // Mic/plugin unavailable → simulation mode keeps the flow usable.
      _simulated = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone unavailable — simulating the recording'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (!mounted) return;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= _maxDuration) _stopRecording();
    });
    setState(_kickWave);
  }

  Future<void> _stopRecording() async {
    if (_phase != _VoicePhase.recording) return;
    _ticker?.cancel();
    setState(() => _phase = _VoicePhase.transcribing);
    if (!_simulated) {
      try {
        final path = await _recorder.stop();
        if (path != null) _audioPath = path;
      } catch (_) {
        // Keep whatever path we have; transcription note covers the rest.
      }
    }
    await _transcribe();
  }

  Future<void> _transcribe() async {
    const system =
        'You are KumbhSathi AI, assisting families at Kumbh Mela 2027. '
        'Convert family voice reports about missing persons into structured '
        'summaries for police triage. Be concise, compassionate and factual.';
    final prompt =
        'A family member just finished a ${_fmt(_elapsed)} voice report in '
        '$_language describing a missing person at the Kumbh Mela. '
        'Note: audio transcription happens on-device and the transcript will '
        'be attached to the case file shortly — it is not included here. '
        'Produce a structured missing-person summary with exactly these '
        'labelled fields: Name, Age, Gender, Physical description, Clothing, '
        'Last seen location, Last seen time, Medical conditions, Languages '
        'spoken. Use "(pending transcript)" for any field awaiting the '
        'transcript, then add one short reassuring closing line for the '
        'family.';
    try {
      final result = await ref
          .read(aiOrchestratorProvider)
          .generate(prompt, system: system, temperature: 0.4);
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _VoicePhase.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _VoicePhase.failed);
    }
  }

  Future<void> _copySummary() async {
    final summary = _result?.text;
    if (summary == null) return;
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Summary copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
        title: const Text('Voice Report'),
        actions: const [
          AiModeChip(dense: true),
          SizedBox(width: AppSpacing.base),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base,
                    AppSpacing.md, AppSpacing.base, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speak in your own words — AI structures the report for search teams.',
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final lang in const ['हिन्दी', 'English', 'मराठी'])
                          _VoiceLangChip(
                            label: lang,
                            selected: _language == lang,
                            onTap: () => setState(() => _language = lang),
                          ),
                      ],
                    )
                        .animate(delay: 50.ms)
                        .fadeIn(duration: 240.ms)
                        .slideY(begin: 0.06),
                    const SizedBox(height: AppSpacing.base),
                    _buildRecorderCard(scheme, text)
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 240.ms)
                        .slideY(begin: 0.06),
                    if (_phase == _VoicePhase.idle)
                      _buildTipsCard(scheme, text)
                          .animate(delay: 150.ms)
                          .fadeIn(duration: 240.ms)
                          .slideY(begin: 0.06),
                    if (_phase == _VoicePhase.transcribing ||
                        _phase == _VoicePhase.done ||
                        _phase == _VoicePhase.failed)
                      _buildTranscriptionSection(scheme, text),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Recorder card ----------------
  Widget _buildRecorderCard(ColorScheme scheme, TextTheme text) {
    final recording = _phase == _VoicePhase.recording;
    final busy = _phase == _VoicePhase.transcribing;

    return AppCard(
      raised: true,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: Column(
        children: [
          // Timer row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (recording) ...[
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _elapsed.inSeconds.isEven ? 1 : 0.25,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                _fmt(_elapsed),
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: recording ? scheme.primary : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ 03:00',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            switch (_phase) {
              _VoicePhase.idle => 'READY TO RECORD',
              _VoicePhase.recording => 'RECORDING',
              _VoicePhase.transcribing => 'PROCESSING',
              _VoicePhase.done => 'COMPLETE',
              _VoicePhase.failed => 'SUMMARY FAILED',
            },
            style: text.labelSmall?.copyWith(
              color: recording ? AppColors.danger : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          // Live waveform
          SizedBox(
            width: double.infinity,
            height: 88,
            child: CustomPaint(
              painter: _VoiceWavePainter(
                animation: _wave,
                prev: _prevBars,
                next: _nextBars,
                color: recording ? scheme.primary : scheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          // Mic / stop button
          Semantics(
            button: true,
            label: recording ? 'Stop recording' : 'Start recording',
            child: GestureDetector(
              onTap: busy
                  ? null
                  : recording
                      ? _stopRecording
                      : _startRecording,
              child: AnimatedContainer(
                duration: AppMotion.enter,
                curve: AppMotion.easeOut,
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: recording ? null : AppColors.accentGradient,
                  color: recording ? AppColors.danger : null,
                  boxShadow: recording
                      ? [
                          BoxShadow(
                            color: AppColors.danger.withValues(alpha: 0.25),
                            offset: const Offset(0, 6),
                            blurRadius: 18,
                          ),
                        ]
                      : AppShadows.cta,
                ),
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          recording ? Symbols.stop : Symbols.mic,
                          fill: 1,
                          size: 36,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            busy
                ? 'Structuring your report…'
                : recording
                    ? 'Tap to stop & transcribe'
                    : 'Tap the mic to start',
            style: text.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_simulated) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.warning,
                      size: 15, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    'Simulation mode — microphone unavailable',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.onWarningContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- Tips card (idle only) ----------------
  Widget _buildTipsCard(ColorScheme scheme, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('What to mention', icon: Symbols.checklist),
        AppCard(
          child: Column(
            children: [
              for (final (i, (icon, tip)) in const <(IconData, String)>[
                (Symbols.person, 'Their name, age and how they look'),
                (Symbols.apparel, 'Colour of clothes and any bag or stick'),
                (Symbols.location_on, 'Where you last saw them'),
                (Symbols.schedule, 'When they went missing'),
              ].indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Icon(icon,
                          size: 18, color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        tip,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- Transcription section ----------------
  Widget _buildTranscriptionSection(ColorScheme scheme, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('AI case summary', icon: Symbols.auto_awesome),
        if (_phase == _VoicePhase.transcribing)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Structuring your report…',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const AiModeChip(dense: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
                const ShimmerBox(height: 14, width: 220),
                const SizedBox(height: AppSpacing.sm),
                const ShimmerBox(height: 14),
                const SizedBox(height: AppSpacing.sm),
                const ShimmerBox(height: 14),
                const SizedBox(height: AppSpacing.sm),
                const ShimmerBox(height: 14, width: 160),
              ],
            ),
          ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06)
        else if (_phase == _VoicePhase.failed)
          AppCard(
            child: EmptyState(
              icon: Symbols.error,
              color: AppColors.danger,
              title: 'Could not generate the summary',
              subtitle:
                  'The AI service did not respond. Retry, or continue with the report form instead.',
              actionLabel: 'Retry',
              onAction: () {
                setState(() => _phase = _VoicePhase.transcribing);
                _transcribe();
              },
            ),
          ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06)
        else if (_result != null)
          _buildResultCard(scheme, text, _result!)
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
      ],
    );
  }

  Widget _buildResultCard(ColorScheme scheme, TextTheme text, AiResult result) {
    final (srcLabel, srcFg, srcBg) = switch (result.source) {
      AiMode.groqCloud => (
          'Groq Cloud',
          AppColors.primary,
          AppColors.primaryContainer
        ),
      AiMode.gemmaOnDevice => (
          'Gemma on-device',
          AppColors.success,
          AppColors.successContainer
        ),
      AiMode.unavailable => (
          'Offline template',
          AppColors.warning,
          AppColors.warningContainer
        ),
    };

    return AppCard(
      accentColor: scheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Icon(Symbols.auto_awesome,
                    size: 20, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Structured summary',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: srcBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  srcLabel,
                  style: text.labelSmall?.copyWith(
                    color: srcFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            result.text,
            style: text.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoContainer,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.verified_user,
                    size: 18, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _audioPath != null && !_simulated
                        ? 'Audio saved on this device — transcription runs fully on-device and attaches to your report automatically.'
                        : 'Transcription runs fully on-device — your voice never leaves this phone.',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          PrimaryCta.tonal(
            label: 'Copy summary',
            icon: Symbols.content_copy,
            onPressed: _copySummary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Symbols.refresh, size: 18),
              label: const Text('Record again'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Language chip
// ============================================================
class _VoiceLangChip extends StatelessWidget {
  const _VoiceLangChip({
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
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Symbols.check, size: 15, color: scheme.onPrimaryContainer),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
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
// Live waveform painter — lerps between randomized bar heights,
// repainted every frame by the driving AnimationController.
// ============================================================
class _VoiceWavePainter extends CustomPainter {
  _VoiceWavePainter({
    required Animation<double> animation,
    required this.prev,
    required this.next,
    required this.color,
  })  : _animation = animation,
        super(repaint: animation);

  final Animation<double> _animation;
  final List<double> prev;
  final List<double> next;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = prev.length;
    if (n == 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final slot = size.width / n;
    final barWidth = slot * 0.55;
    final t = Curves.easeInOut.transform(_animation.value.clamp(0.0, 1.0));
    for (var i = 0; i < n; i++) {
      final v = prev[i] + (next[i] - prev[i]) * t;
      final h = (size.height * v).clamp(3.0, size.height);
      final x = slot * i + (slot - barWidth) / 2;
      final y = (size.height - h) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.prev != prev ||
      oldDelegate.next != next;
}

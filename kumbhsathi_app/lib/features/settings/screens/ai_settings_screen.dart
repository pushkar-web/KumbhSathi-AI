import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../services/ai/gemma_service.dart';
import '../../../services/face/face_recognition_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/section_header.dart';

/// AI & Models control panel (DESIGN.md §7.4): connectivity, Groq key,
/// Gemma 3n + face model download lifecycle, test row.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _groqCtrl = TextEditingController();
  final _hfCtrl = TextEditingController();
  bool _obscureGroq = true;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    // Ensure model services have probed disk.
    ref.read(aiBootstrapProvider);
  }

  @override
  void dispose() {
    _groqCtrl.dispose();
    _hfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = ref.watch(isOnlineProvider);
    final creds = ref.watch(aiCredentialsProvider);
    final gemma = ref.watch(gemmaServiceProvider);
    final face = ref.watch(faceServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI & Models')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          // ---- Status overview ----
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: online
                        ? AppColors.successContainer
                        : AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Icon(
                    online ? Symbols.wifi : Symbols.wifi_off,
                    color: online ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(online ? 'Online' : 'Offline',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        online
                            ? 'AI requests routed to Groq Cloud when a key is set'
                            : 'AI requests routed to the on-device Gemma model',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const AiModeChip(),
              ],
            ),
          ),

          const SectionHeader('Groq Cloud (online AI)', icon: Symbols.bolt),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creds.hasGroqKey
                      ? 'API key configured ✓'
                      : 'Add your Groq API key to enable fast cloud inference '
                        '(llama-3.3-70b). Free keys: console.groq.com',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: creds.hasGroqKey
                          ? AppColors.success
                          : theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _groqCtrl,
                  obscureText: _obscureGroq,
                  decoration: InputDecoration(
                    hintText: 'gsk_...',
                    prefixIcon: const Icon(Symbols.key, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureGroq
                              ? Symbols.visibility
                              : Symbols.visibility_off,
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscureGroq = !_obscureGroq),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryCta.tonal(
                        label: 'Save key',
                        icon: Symbols.save,
                        onPressed: () async {
                          await ref
                              .read(aiCredentialsProvider.notifier)
                              .setGroqKey(_groqCtrl.text);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Groq API key saved')));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PrimaryCta(
                        label: _testing ? 'Testing…' : 'Test AI',
                        icon: Symbols.science,
                        loading: _testing,
                        onPressed: _testing ? null : _runTest,
                      ),
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Text(_testResult!,
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ],
            ),
          ),

          const SectionHeader('Gemma 3n — offline AI', icon: Symbols.smartphone),
          _GemmaCard(gemma: gemma, hfCtrl: _hfCtrl),

          const SectionHeader('Face recognition model', icon: Symbols.face),
          _FaceModelCard(face: face),

          const SizedBox(height: AppSpacing.xl),
          Text(
            'Models are stored on-device and never leave it. Face matching '
            'and Aadhaar verification run fully offline; case data syncs '
            'when a connection returns.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _runTest() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final result = await ref.read(aiOrchestratorProvider).generate(
          'Reply with one short sentence confirming you are ready to help '
          'find missing persons at Kumbh Mela.',
        );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = '[${result.source.name}] ${result.text}';
    });
  }
}

class _GemmaCard extends ConsumerWidget {
  const _GemmaCard({required this.gemma, required this.hfCtrl});

  final GemmaService gemma;
  final TextEditingController hfCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final creds = ref.watch(aiCredentialsProvider);

    final (statusLabel, statusColor) = switch (gemma.status) {
      GemmaStatus.ready => ('Installed & ready', AppColors.success),
      GemmaStatus.downloading => (
          'Downloading ${(gemma.downloadProgress * 100).toStringAsFixed(0)}%',
          AppColors.info
        ),
      GemmaStatus.initializing => ('Initializing…', AppColors.info),
      GemmaStatus.error => ('Error', AppColors.danger),
      GemmaStatus.notDownloaded => ('Not installed', AppColors.inkMedium),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Gemma 3n E2B (int4, ~3.1 GB)',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: statusColor, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Powers the AI interview, summaries and translations when '
            'offline. Downloading requires a free Hugging Face token '
            '(Gemma weights are gated).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (gemma.status == GemmaStatus.downloading) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                  value: gemma.downloadProgress, minHeight: 8),
            ),
          ],
          if (gemma.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(gemma.errorMessage!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.md),
          if (gemma.status != GemmaStatus.ready &&
              gemma.status != GemmaStatus.downloading) ...[
            TextField(
              controller: hfCtrl,
              decoration: const InputDecoration(
                hintText: 'Hugging Face token (hf_...)',
                prefixIcon: Icon(Symbols.token, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryCta(
              label: 'Download Gemma 3n',
              icon: Symbols.download,
              onPressed: () async {
                final token = hfCtrl.text.trim().isNotEmpty
                    ? hfCtrl.text.trim()
                    : creds.hfToken;
                if (token != null && token.isNotEmpty) {
                  await ref
                      .read(aiCredentialsProvider.notifier)
                      .setHfToken(token);
                }
                await ref
                    .read(gemmaServiceProvider)
                    .downloadModel(hfToken: token);
              },
            ),
          ],
          if (gemma.status == GemmaStatus.ready)
            PrimaryCta.tonal(
              label: 'Delete model',
              icon: Symbols.delete,
              onPressed: () => ref.read(gemmaServiceProvider).deleteModel(),
            ),
        ],
      ),
    );
  }
}

class _FaceModelCard extends ConsumerWidget {
  const _FaceModelCard({required this.face});

  final FaceRecognitionService face;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final (label, color) = switch (face.status) {
      FaceServiceStatus.ready => ('Installed & ready', AppColors.success),
      FaceServiceStatus.downloading => (
          'Downloading ${(face.downloadProgress * 100).toStringAsFixed(0)}%',
          AppColors.info
        ),
      FaceServiceStatus.error => ('Error', AppColors.danger),
      FaceServiceStatus.modelMissing => ('Not installed', AppColors.inkMedium),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('MobileFaceNet (~5 MB)',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'On-device face matching for found-person identification. '
            '${face.enrolledCount} face(s) enrolled locally.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (face.status == FaceServiceStatus.downloading) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                  value: face.downloadProgress, minHeight: 8),
            ),
          ],
          if (face.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(face.errorMessage!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.danger)),
          ],
          if (face.status == FaceServiceStatus.modelMissing ||
              face.status == FaceServiceStatus.error) ...[
            const SizedBox(height: AppSpacing.md),
            PrimaryCta(
              label: 'Download face model',
              icon: Symbols.download,
              onPressed: () => ref.read(faceServiceProvider).downloadModel(),
            ),
          ],
        ],
      ),
    );
  }
}

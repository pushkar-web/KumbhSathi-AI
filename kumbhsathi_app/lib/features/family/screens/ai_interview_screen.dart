import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/ai_providers.dart';
import '../../../services/ai/ai_router.dart';
import '../../../services/ai/groq_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/person_avatar.dart';

/// AI guided interview chat (DESIGN.md §6.1) — fully wired to the
/// [AiOrchestrator] router. Groq online, Gemma 3n offline, template fallback.
class AiInterviewScreen extends ConsumerStatefulWidget {
  const AiInterviewScreen({super.key});

  @override
  ConsumerState<AiInterviewScreen> createState() => _AiInterviewScreenState();
}

class _AiInterviewScreenState extends ConsumerState<AiInterviewScreen> {
  /// Full conversation, in orchestrator wire format.
  final List<AiMessage> _history = [];

  /// Which backend produced each turn (parallel to [_history]; null = user).
  final List<AiMode?> _sources = [];

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final DateTime _sessionStart = DateTime.now();

  bool _typing = false;
  bool _startFailed = false;

  static const List<String> _quickReplies = [
    'Blue kurta',
    'Near Ramkund',
    'He is 8 years old',
    'Speaks Marathi',
    'Around 6 in the evening',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ============================================================
  // AI wiring
  // ============================================================

  Future<void> _start() async {
    setState(() {
      _startFailed = false;
      _typing = true;
    });
    try {
      final result =
          await ref.read(aiOrchestratorProvider).interviewReply(const []);
      if (!mounted) return;
      setState(() {
        _history.add(AiMessage.assistant(result.text));
        _sources.add(result.source);
        _typing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _startFailed = true;
      });
    }
    _scrollToEnd();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    setState(() {
      _history.add(AiMessage.user(text));
      _sources.add(null);
      _typing = true;
    });
    _scrollToEnd();
    try {
      final result = await ref
          .read(aiOrchestratorProvider)
          .interviewReply(List.of(_history));
      if (!mounted) return;
      setState(() {
        _history.add(AiMessage.assistant(result.text));
        _sources.add(result.source);
        _typing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _typing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not reach the assistant — please try again.'),
        ),
      );
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.enter,
        curve: AppMotion.easeOut,
      );
    });
  }

  void _onMic() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Voice input is available from the Voice Recording screen.'),
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(aiModeProvider);
    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            if (mode == AiMode.unavailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base, AppSpacing.md, AppSpacing.base, 0),
                child: const _AiIvUnavailableCard()
                    .animate()
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: 0.06),
              ),
            Expanded(child: _buildConversation(context)),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AppBar(
      backgroundColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      titleSpacing: AppSpacing.xs,
      title: Row(
        children: [
          const PersonAvatar('KumbhSathi AI',
              size: 38, statusDot: AppColors.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KumbhSathi AI',
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const AiModeChip(dense: true),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _history.isEmpty ? null : () => _showReviewSheet(context),
          child: const Text(
            'End & Review',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _buildConversation(BuildContext context) {
    if (_history.isEmpty && _startFailed) {
      return EmptyState(
        icon: Symbols.smart_toy,
        title: 'Could not start the interview',
        subtitle: 'The assistant did not respond. Check your connection or '
            'on-device model, then try again.',
        actionLabel: 'Retry',
        onAction: _start,
      );
    }
    if (_history.isEmpty) return const _AiIvIntroShimmer();

    final showChips = !_typing &&
        !_startFailed &&
        _history.isNotEmpty &&
        _history.last.role == 'assistant';
    final itemCount =
        1 + _history.length + (showChips ? 1 : 0) + (_typing ? 1 : 0);

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.lg),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) return _AiIvSessionPill(start: _sessionStart);

        final msgIndex = index - 1;
        if (msgIndex < _history.length) {
          final msg = _history[msgIndex];
          final bubble = msg.role == 'assistant'
              ? _AiIvAiBubble(body: msg.content, source: _sources[msgIndex])
              : _AiIvUserBubble(body: msg.content);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.base),
            child: bubble.animate().fadeIn(duration: 240.ms).slideY(
                begin: 0.06, duration: 240.ms, curve: AppMotion.easeOut),
          );
        }

        if (showChips && msgIndex == _history.length) {
          return _AiIvQuickReplies(
            suggestions: _quickReplies,
            onTap: _send,
          ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06);
        }

        return const _AiIvTypingBubble()
            .animate()
            .fadeIn(duration: 180.ms)
            .slideY(begin: 0.06);
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: AppShadows.raised,
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm + 2, AppSpacing.md, AppSpacing.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              textCapitalization: TextCapitalization.sentences,
              style: text.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Type your answer…',
                hintStyle:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: AppSpacing.md),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Symbols.mic, size: 22),
                  color: scheme.primary,
                  tooltip: 'Voice input',
                  onPressed: _onMic,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          _AiIvSendFab(enabled: !_typing, onTap: () => _send(_input.text)),
        ],
      ),
    );
  }

  // ============================================================
  // End & Review sheet
  // ============================================================

  void _showReviewSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiIvReviewSheet(history: List.of(_history)),
    );
  }
}

// ============================================================
// Session pill
// ============================================================

class _AiIvSessionPill extends StatelessWidget {
  const _AiIvSessionPill({required this.start});

  final DateTime start;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            'Interview started ${DateFormat('d MMM, h:mm a').format(start)}'
                .toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Bubbles
// ============================================================

class _AiIvAiBubble extends StatelessWidget {
  const _AiIvAiBubble({required this.body, this.source});

  final String body;
  final AiMode? source;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            const PersonAvatar('KumbhSathi AI', size: 32),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: AppCard(
                accentColor: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.base, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(body, style: text.bodyMedium?.copyWith(height: 1.5)),
                    if (source != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _AiIvSourceTag(source: source!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiIvSourceTag extends StatelessWidget {
  const _AiIvSourceTag({required this.source});

  final AiMode source;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (source) {
      AiMode.groqCloud => (Symbols.bolt, 'Groq Cloud', AppColors.primary),
      AiMode.gemmaOnDevice => (
          Symbols.smartphone,
          'Gemma on-device',
          AppColors.success
        ),
      AiMode.unavailable => (
          Symbols.cloud_off,
          'Offline template',
          AppColors.warning
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _AiIvUserBubble extends StatelessWidget {
  const _AiIvUserBubble({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.card),
              topRight: Radius.circular(AppRadius.card),
              bottomLeft: Radius.circular(AppRadius.card),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: AppShadows.card,
          ),
          child: Text(
            body,
            style: text.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Quick replies
// ============================================================

class _AiIvQuickReplies extends StatelessWidget {
  const _AiIvQuickReplies({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: AppSpacing.base),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final s in suggestions)
            Material(
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base, vertical: 10),
                  child: Text(
                    s,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Typing indicator
// ============================================================

class _AiIvTypingBubble extends StatelessWidget {
  const _AiIvTypingBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const PersonAvatar('KumbhSathi AI', size: 32),
          const SizedBox(width: AppSpacing.sm),
          Container(
            height: 44,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card),
                topRight: Radius.circular(AppRadius.card),
                bottomRight: Radius.circular(AppRadius.card),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: AppShadows.card,
            ),
            child: const _AiIvTypingDots(),
          ),
        ],
      ),
    );
  }
}

/// Three bouncing dots on a single repeating controller so the wave stays
/// perfectly in phase.
class _AiIvTypingDots extends StatefulWidget {
  const _AiIvTypingDots();

  @override
  State<_AiIvTypingDots> createState() => _AiIvTypingDotsState();
}

class _AiIvTypingDotsState extends State<_AiIvTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _pulse(int i) {
    final t = (_controller.value - i * 0.16) % 1.0;
    if (t > 0.5) return 0;
    return math.sin(t / 0.5 * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Transform.translate(
              offset: Offset(0, -5 * _pulse(i)),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(alpha: 0.45 + 0.55 * _pulse(i)),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// AI-unavailable banner card
// ============================================================

class _AiIvUnavailableCard extends StatelessWidget {
  const _AiIvUnavailableCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: AppColors.warningContainer,
      accentColor: AppColors.warning,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      child: Row(
        children: [
          const Icon(Symbols.cloud_off, size: 20, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI is unavailable',
                  style: text.labelLarge?.copyWith(
                    color: AppColors.onWarningContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Connect to the internet or download the on-device model.',
                  style: text.labelMedium
                      ?.copyWith(color: AppColors.onWarningContainer),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(Routes.aiSettings),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onWarningContainer,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('AI Settings'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Send FAB
// ============================================================

class _AiIvSendFab extends StatelessWidget {
  const _AiIvSendFab({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.exit,
      opacity: enabled ? 1 : 0.55,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          shape: BoxShape.circle,
          boxShadow: enabled ? AppShadows.cta : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: const Icon(Symbols.send,
                fill: 1, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Intro shimmer (initial load skeleton mirrors chat layout)
// ============================================================

class _AiIvIntroShimmer extends StatelessWidget {
  const _AiIvIntroShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: const [
        Center(child: ShimmerBox(width: 180, height: 22, radius: 999)),
        SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ShimmerBox(width: 32, height: 32, radius: 16),
            SizedBox(width: AppSpacing.sm),
            ShimmerBox(width: 230, height: 76, radius: AppRadius.card),
          ],
        ),
        SizedBox(height: AppSpacing.base),
        Padding(
          padding: EdgeInsets.only(left: 40),
          child: Row(
            children: [
              ShimmerBox(width: 92, height: 36, radius: 999),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 110, height: 36, radius: 999),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 84, height: 36, radius: 999),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// End & Review summary sheet
// ============================================================

class _AiIvReviewSheet extends StatelessWidget {
  const _AiIvReviewSheet({required this.history});

  final List<AiMessage> history;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Pair each AI question with the family member's following answer.
    final pairs = <({String q, String a})>[];
    String? pendingQ;
    for (final m in history) {
      if (m.role == 'assistant') {
        pendingQ = m.content;
      } else if (m.role == 'user') {
        pairs.add((q: pendingQ ?? 'Additional detail', a: m.content));
        pendingQ = null;
      }
    }
    final lastAiNote =
        history.isNotEmpty && history.last.role == 'assistant' && pairs.isNotEmpty
            ? history.last.content
            : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.modal)),
        boxShadow: AppShadows.raised,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Icon(Symbols.summarize,
                        size: 22, color: scheme.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interview review',
                          style: text.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${pairs.length} '
                          '${pairs.length == 1 ? 'answer' : 'answers'} captured',
                          style: text.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const AiModeChip(dense: true),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              Flexible(
                child: pairs.isEmpty
                    ? const EmptyState(
                        icon: Symbols.forum,
                        title: 'No answers yet',
                        subtitle: 'Reply to the assistant first — your '
                            'answers will be summarised here.',
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          if (lastAiNote != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md),
                              child: AppCard(
                                accentColor: AppColors.primary,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ASSISTANT SUMMARY',
                                      style: text.labelSmall?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      lastAiNote,
                                      style: text.bodyMedium
                                          ?.copyWith(height: 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(duration: 240.ms).slideY(
                                begin: 0.06, curve: AppMotion.easeOut),
                          for (final (i, p) in pairs.indexed)
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md),
                              child: AppCard(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.q,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.labelMedium?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      p.a,
                                      style: text.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            )
                                .animate(delay: (math.min(i, 5) * 50).ms)
                                .fadeIn(duration: 240.ms)
                                .slideY(
                                    begin: 0.06, curve: AppMotion.easeOut),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.base),
              PrimaryCta(
                label: 'Continue interview',
                icon: Symbols.forum,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

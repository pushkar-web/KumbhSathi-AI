import 'gemma_service.dart';
import 'groq_service.dart';

/// Which backend answered (surfaced in the UI via AiModeChip — DESIGN.md §7.3).
enum AiMode { groqCloud, gemmaOnDevice, unavailable }

class AiResult {
  const AiResult(this.text, this.source);
  final String text;
  final AiMode source;
}

/// Routes every AI request: Groq when online with a key, Gemma 3n on-device
/// otherwise, graceful template fallback when neither is available.
/// Never throws — features degrade, they don't crash (DESIGN.md §8).
class AiOrchestrator {
  AiOrchestrator({
    required GroqService groq,
    required GemmaService gemma,
    required bool Function() isOnline,
  })  : _groq = groq,
        _gemma = gemma,
        _isOnline = isOnline;

  final GroqService _groq;
  final GemmaService _gemma;
  final bool Function() _isOnline;

  Future<AiMode> currentMode() async {
    if (_isOnline() && await _groq.hasKey) return AiMode.groqCloud;
    if (_gemma.isReady) return AiMode.gemmaOnDevice;
    return AiMode.unavailable;
  }

  /// General-purpose generation with automatic fallback chain.
  Future<AiResult> generate(
    String prompt, {
    String? system,
    List<AiMessage> history = const [],
    double temperature = 0.6,
  }) async {
    final messages = <AiMessage>[
      if (system != null) AiMessage.system(system),
      ...history,
      AiMessage.user(prompt),
    ];

    if (_isOnline() && await _groq.hasKey) {
      try {
        final text = await _groq.chat(messages, temperature: temperature);
        return AiResult(text, AiMode.groqCloud);
      } catch (_) {
        // fall through to on-device
      }
    }

    if (_gemma.isReady) {
      try {
        final text = await _gemma.generate(messages, temperature: temperature);
        return AiResult(text, AiMode.gemmaOnDevice);
      } catch (_) {
        // fall through to template
      }
    }

    return AiResult(_templateFallback(prompt), AiMode.unavailable);
  }

  /// Guided-interview turn: asks the next best question to complete a
  /// missing-person report (used by the AI Interview screen).
  Future<AiResult> interviewReply(List<AiMessage> conversation) {
    const system =
        'You are KumbhSathi, a calm and compassionate assistant helping a '
        'distressed family member report a missing person at the Kumbh Mela. '
        'Ask ONE short, specific follow-up question at a time to gather: '
        'name, age, gender, physical description, clothing, last seen '
        'location and time, medical conditions, and languages spoken. '
        'Acknowledge answers briefly. Be reassuring, never clinical. '
        'When you have enough information, summarize the report and say it '
        'is ready to submit.';
    final last = conversation.isEmpty
        ? 'Begin the interview with a gentle opening question.'
        : conversation.last.content;
    final history = conversation.isEmpty
        ? const <AiMessage>[]
        : conversation.sublist(0, conversation.length - 1);
    return generate(last, system: system, history: history, temperature: 0.7);
  }

  String _templateFallback(String prompt) {
    return 'AI assistance is currently unavailable (no connection and no '
        'on-device model installed). You can continue filling the form '
        'manually — every feature works without AI. To enable offline AI, '
        'download the Gemma 3n model from AI Settings.';
  }
}

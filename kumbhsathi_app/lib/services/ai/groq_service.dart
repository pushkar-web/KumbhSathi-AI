import 'package:dio/dio.dart';

/// One chat turn for any AI backend (Groq or Gemma).
class AiMessage {
  const AiMessage.system(this.content) : role = 'system';
  const AiMessage.user(this.content) : role = 'user';
  const AiMessage.assistant(this.content) : role = 'assistant';

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Groq cloud inference (OpenAI-compatible chat completions).
/// Used when the device is online and a key is configured; the on-device
/// Gemma 3n model covers offline (DESIGN.md §7.3).
class GroqService {
  GroqService({required Future<String?> Function() apiKey})
      : _apiKey = apiKey,
        _dio = Dio(BaseOptions(
          baseUrl: 'https://api.groq.com/openai/v1',
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 60),
        ));

  final Future<String?> Function() _apiKey;
  final Dio _dio;

  static const String defaultModel = 'llama-3.3-70b-versatile';

  Future<bool> get hasKey async {
    final k = await _apiKey();
    return k != null && k.trim().isNotEmpty;
  }

  /// Returns the assistant reply text. Throws [GroqException] on failure so
  /// the orchestrator can fall back to on-device Gemma.
  Future<String> chat(
    List<AiMessage> messages, {
    String model = defaultModel,
    double temperature = 0.6,
    int maxTokens = 1024,
    bool jsonMode = false,
  }) async {
    final key = await _apiKey();
    if (key == null || key.trim().isEmpty) {
      throw const GroqException('No Groq API key configured');
    }
    try {
      final res = await _dio.post(
        '/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer ${key.trim()}'}),
        data: {
          'model': model,
          'messages': [for (final m in messages) m.toJson()],
          'temperature': temperature,
          'max_tokens': maxTokens,
          if (jsonMode) 'response_format': {'type': 'json_object'},
        },
      );
      final choices = res.data['choices'] as List?;
      String? text;
      if (choices?.isNotEmpty == true) {
        final messageMap = choices!.first['message'];
        if (messageMap is Map) {
          text = messageMap['content'] as String?;
        }
      }
      if (text == null || text.isEmpty) {
        throw const GroqException('Empty response from Groq');
      }
      return text;
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data['error']?['message'] ?? e.message)
          : e.message;
      throw GroqException('Groq request failed: $detail');
    }
  }
}

class GroqException implements Exception {
  const GroqException(this.message);
  final String message;
  @override
  String toString() => message;
}

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../model_manager.dart';
import 'groq_service.dart' show AiMessage;

/// Lifecycle of the on-device Gemma 3n model (DESIGN.md §7.3/§7.4).
enum GemmaStatus { notDownloaded, downloading, initializing, ready, error }

/// Wraps `flutter_gemma` (MediaPipe LLM inference) around the Gemma 3n
/// mobile model so all AI features keep working fully offline.
///
/// All plugin API usage is isolated to this file on purpose: if the
/// installed flutter_gemma version drifts, fixes stay local. Written
/// against the 0.9.x session API.
class GemmaService extends ChangeNotifier {
  GemmaService(this._models);

  final ModelManager _models;

  /// Gemma 3n E2B instruction-tuned, int4 LiteRT `.task` (~3.1 GB).
  /// Downloading from Hugging Face requires a user token (entered in
  /// AI Settings) because Google gates the Gemma weights.
  static const String defaultModelUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task';
  static const String modelFilename = 'gemma-3n-E2B-it-int4.task';

  GemmaStatus status = GemmaStatus.notDownloaded;
  double downloadProgress = 0;
  String? errorMessage;

  InferenceModel? _model;

  bool get isReady => status == GemmaStatus.ready;

  /// Checks disk and, when the model file exists, initializes inference.
  Future<void> init() async {
    try {
      if (!await _models.isDownloaded(modelFilename)) {
        status = GemmaStatus.notDownloaded;
        notifyListeners();
        return;
      }
      await _initModel();
    } catch (e) {
      _fail('Gemma init failed: $e');
    }
  }

  Future<void> downloadModel({String? url, String? hfToken}) async {
    if (status == GemmaStatus.downloading) return;
    status = GemmaStatus.downloading;
    downloadProgress = 0;
    errorMessage = null;
    notifyListeners();
    try {
      await for (final p in _models.download(
        url: url ?? defaultModelUrl,
        filename: modelFilename,
        headers: hfToken == null || hfToken.isEmpty
            ? null
            : {'Authorization': 'Bearer $hfToken'},
      )) {
        downloadProgress = p;
        notifyListeners();
      }
      await _initModel();
    } catch (e) {
      _fail('$e');
    }
  }

  Future<void> _initModel() async {
    status = GemmaStatus.initializing;
    notifyListeners();

    final path = await _models.pathFor(modelFilename);
    final gemma = FlutterGemmaPlugin.instance;
    await gemma.modelManager.setModelPath(path);
    _model = await gemma.createModel(
      modelType: ModelType.gemmaIt,
      maxTokens: 1024,
    );

    status = GemmaStatus.ready;
    notifyListeners();
  }

  /// Single-shot generation over a fresh session. History is folded into
  /// the prompt (sessions are cheap; keeps memory bounded on mobile).
  Future<String> generate(
    List<AiMessage> messages, {
    double temperature = 0.7,
  }) async {
    final model = _model;
    if (model == null) throw StateError('Gemma model not ready');

    final prompt = _foldPrompt(messages);
    final session = await model.createSession(temperature: temperature);
    try {
      await session.addQueryChunk(Message(text: prompt, isUser: true));
      final reply = await session.getResponse();
      return reply.trim();
    } finally {
      await session.close();
    }
  }

  String _foldPrompt(List<AiMessage> messages) {
    final buf = StringBuffer();
    for (final m in messages) {
      switch (m.role) {
        case 'system':
          buf.writeln('[Instructions]\n${m.content}\n');
        case 'assistant':
          buf.writeln('Assistant: ${m.content}');
        default:
          buf.writeln('User: ${m.content}');
      }
    }
    buf.write('Assistant:');
    return buf.toString();
  }

  Future<void> deleteModel() async {
    await _model?.close();
    _model = null;
    await _models.delete(modelFilename);
    status = GemmaStatus.notDownloaded;
    downloadProgress = 0;
    notifyListeners();
  }

  Future<int> modelSizeBytes() => _models.sizeOf(modelFilename);

  void _fail(String message) {
    status = GemmaStatus.error;
    errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _model?.close();
    super.dispose();
  }
}

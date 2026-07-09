import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/aadhaar/aadhaar_service.dart';
import '../services/ai/ai_router.dart';
import '../services/ai/gemma_service.dart';
import '../services/ai/groq_service.dart';
import '../services/face/face_recognition_service.dart';
import '../services/model_manager.dart';
import 'connectivity_provider.dart';
import 'core_providers.dart';

// ============================================================
// Credentials (Groq API key, Hugging Face token)
// ============================================================
class AiCredentials {
  const AiCredentials({this.groqApiKey, this.hfToken, this.loaded = false});
  final String? groqApiKey;
  final String? hfToken;
  final bool loaded;

  bool get hasGroqKey => groqApiKey != null && groqApiKey!.trim().isNotEmpty;

  AiCredentials copyWith({String? groqApiKey, String? hfToken}) =>
      AiCredentials(
        groqApiKey: groqApiKey ?? this.groqApiKey,
        hfToken: hfToken ?? this.hfToken,
        loaded: true,
      );
}

class AiCredentialsNotifier extends StateNotifier<AiCredentials> {
  AiCredentialsNotifier(this._ref) : super(const AiCredentials()) {
    _load();
  }

  static const _kGroqKey = 'groq_api_key';
  static const _kHfToken = 'hf_token';

  /// Build-time default: flutter run --dart-define=GROQ_API_KEY=...
  static const _envGroqKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  final Ref _ref;

  Future<void> _load() async {
    final storage = _ref.read(secureStorageProvider);
    final stored = await storage.read(_kGroqKey);
    final hf = await storage.read(_kHfToken);
    state = AiCredentials(
      groqApiKey:
          (stored?.isNotEmpty ?? false) ? stored : (_envGroqKey.isEmpty ? null : _envGroqKey),
      hfToken: hf,
      loaded: true,
    );
  }

  Future<void> setGroqKey(String key) async {
    await _ref.read(secureStorageProvider).write(_kGroqKey, key.trim());
    state = state.copyWith(groqApiKey: key.trim());
  }

  Future<void> setHfToken(String token) async {
    await _ref.read(secureStorageProvider).write(_kHfToken, token.trim());
    state = state.copyWith(hfToken: token.trim());
  }
}

final aiCredentialsProvider =
    StateNotifierProvider<AiCredentialsNotifier, AiCredentials>(
        (ref) => AiCredentialsNotifier(ref));

// ============================================================
// Services
// ============================================================
final modelManagerProvider = Provider<ModelManager>((ref) => ModelManager());

final groqServiceProvider = Provider<GroqService>((ref) {
  return GroqService(
    apiKey: () async => ref.read(aiCredentialsProvider).groqApiKey,
  );
});

final gemmaServiceProvider = ChangeNotifierProvider<GemmaService>((ref) {
  return GemmaService(ref.watch(modelManagerProvider));
});

final faceServiceProvider =
    ChangeNotifierProvider<FaceRecognitionService>((ref) {
  return FaceRecognitionService(ref.watch(modelManagerProvider));
});

final aadhaarServiceProvider = Provider<AadhaarService>((ref) {
  final service = AadhaarService();
  ref.onDispose(service.dispose);
  return service;
});

/// One-time async init of on-device models; watch once from the shell.
final aiBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(gemmaServiceProvider).init();
  await ref.read(faceServiceProvider).init();
});

// ============================================================
// Orchestration
// ============================================================
final aiOrchestratorProvider = Provider<AiOrchestrator>((ref) {
  return AiOrchestrator(
    groq: ref.watch(groqServiceProvider),
    gemma: ref.watch(gemmaServiceProvider),
    isOnline: () => ref.read(isOnlineProvider),
  );
});

/// Which backend would answer right now — drives [AiModeChip] everywhere.
final aiModeProvider = Provider<AiMode>((ref) {
  final online = ref.watch(isOnlineProvider);
  final creds = ref.watch(aiCredentialsProvider);
  final gemma = ref.watch(gemmaServiceProvider);
  if (online && creds.hasGroqKey) return AiMode.groqCloud;
  if (gemma.isReady) return AiMode.gemmaOnDevice;
  return AiMode.unavailable;
});

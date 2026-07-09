import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart' hide ModelManager;
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../model_manager.dart';

/// Face pipeline status, surfaced in AI Settings and scan screens.
enum FaceServiceStatus { modelMissing, downloading, ready, error }

/// A candidate returned by the offline matcher.
class FaceMatchCandidate {
  const FaceMatchCandidate({
    required this.caseId,
    required this.name,
    required this.score,
    this.photoPath,
    this.meta = const {},
  });

  final String caseId;
  final String name;

  /// Cosine similarity 0..1 (≥ 0.75 strong, 0.60–0.75 probable, < 0.60 weak).
  final double score;
  final String? photoPath;
  final Map<String, dynamic> meta;
}

/// Fully offline face recognition (DESIGN.md §7.1):
///   ML Kit detects the face → crop with margin → MobileFaceNet (TFLite)
///   produces a 192-d embedding → cosine match against the local Hive index.
///
/// Embeddings are enrolled when a missing person is registered and matched
/// when a volunteer/officer scans a found person. No network required.
class FaceRecognitionService extends ChangeNotifier {
  FaceRecognitionService(this._models);

  final ModelManager _models;

  /// MobileFaceNet TFLite (~5 MB, 192-d output). Bundle at
  /// `assets/models/mobile_face_net.tflite` or download once from
  /// [defaultModelUrl] (overridable in AI Settings).
  static const String modelFilename = 'mobile_face_net.tflite';
  static const String assetPath = 'assets/models/mobile_face_net.tflite';
  static const String defaultModelUrl =
      'https://github.com/estebanuri/face_recognition/raw/master/android/app/src/main/assets/mobile_face_net.tflite';

  static const int _inputSize = 112;
  static const int _embeddingDim = 192;
  static const String _boxName = 'face_index';

  FaceServiceStatus status = FaceServiceStatus.modelMissing;
  double downloadProgress = 0;
  String? errorMessage;

  Interpreter? _interpreter;
  Box? _box;

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  bool get isReady => status == FaceServiceStatus.ready;
  int get enrolledCount => _box?.length ?? 0;

  // ============================================================
  // Lifecycle
  // ============================================================
  Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
    try {
      // Prefer a bundled asset; fall back to the downloaded file.
      try {
        _interpreter = await Interpreter.fromAsset(assetPath);
      } catch (_) {
        if (await _models.isDownloaded(modelFilename)) {
          _interpreter =
              Interpreter.fromFile(File(await _models.pathFor(modelFilename)));
        }
      }
      status = _interpreter == null
          ? FaceServiceStatus.modelMissing
          : FaceServiceStatus.ready;
    } catch (e) {
      status = FaceServiceStatus.error;
      errorMessage = 'Face model failed to load: $e';
    }
    notifyListeners();
  }

  Future<void> downloadModel({String? url}) async {
    if (status == FaceServiceStatus.downloading) return;
    status = FaceServiceStatus.downloading;
    downloadProgress = 0;
    errorMessage = null;
    notifyListeners();
    try {
      await for (final p in _models.download(
        url: url ?? defaultModelUrl,
        filename: modelFilename,
      )) {
        downloadProgress = p;
        notifyListeners();
      }
      _interpreter =
          Interpreter.fromFile(File(await _models.pathFor(modelFilename)));
      status = FaceServiceStatus.ready;
    } catch (e) {
      status = FaceServiceStatus.error;
      errorMessage = '$e';
    }
    notifyListeners();
  }

  // ============================================================
  // Embedding
  // ============================================================

  /// Detects the largest face in the image file and returns its embedding,
  /// or `null` when no face is found. Throws [StateError] if model missing.
  Future<List<double>?> embedImageFile(String path) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Face model not installed — download it in AI Settings');
    }

    final faces =
        await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) return null;
    faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
        .compareTo(a.boundingBox.width * a.boundingBox.height));
    final rect = faces.first.boundingBox;

    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final oriented = img.bakeOrientation(decoded);

    // Crop with a 20% margin around the detected box, clamped to bounds.
    final margin = rect.width * 0.2;
    final x = (rect.left - margin).clamp(0, oriented.width - 1).toInt();
    final y = (rect.top - margin).clamp(0, oriented.height - 1).toInt();
    final w =
        (rect.width + margin * 2).clamp(1, oriented.width - x).toInt();
    final h =
        (rect.height + margin * 2).clamp(1, oriented.height - y).toInt();
    final face = img.copyResize(
      img.copyCrop(oriented, x: x, y: y, width: w, height: h),
      width: _inputSize,
      height: _inputSize,
    );

    // Normalize to [-1, 1], NHWC float32.
    final input = Float32List(_inputSize * _inputSize * 3);
    var i = 0;
    for (var py = 0; py < _inputSize; py++) {
      for (var px = 0; px < _inputSize; px++) {
        final p = face.getPixel(px, py);
        input[i++] = (p.r - 127.5) / 127.5;
        input[i++] = (p.g - 127.5) / 127.5;
        input[i++] = (p.b - 127.5) / 127.5;
      }
    }

    final output =
        List.generate(1, (_) => List.filled(_embeddingDim, 0.0));
    interpreter.run(
        input.reshape([1, _inputSize, _inputSize, 3]), output);
    return _l2Normalize(output.first);
  }

  // ============================================================
  // Local index (enroll / match)
  // ============================================================
  Future<void> enroll({
    required String caseId,
    required String name,
    required List<double> embedding,
    String? photoPath,
    Map<String, dynamic> meta = const {},
  }) async {
    _box ??= await Hive.openBox(_boxName);
    await _box!.put(caseId, {
      'name': name,
      'embedding': embedding,
      'photoPath': photoPath,
      'meta': meta,
      'enrolledAt': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }

  Future<List<FaceMatchCandidate>> match(
    List<double> query, {
    int topK = 3,
    double threshold = 0.45,
  }) async {
    _box ??= await Hive.openBox(_boxName);
    final results = <FaceMatchCandidate>[];
    for (final key in _box!.keys) {
      final entry = _box!.get(key);
      if (entry is! Map) continue;
      final raw = entry['embedding'];
      if (raw is! List) continue;
      final emb = raw.map((e) => (e as num).toDouble()).toList();
      final score = _cosine(query, emb);
      if (score >= threshold) {
        results.add(FaceMatchCandidate(
          caseId: key.toString(),
          name: entry['name']?.toString() ?? 'Unknown',
          score: score,
          photoPath: entry['photoPath']?.toString(),
          meta: entry['meta'] is Map
              ? Map<String, dynamic>.from(entry['meta'] as Map)
              : const {},
        ));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }

  Future<void> removeEnrollment(String caseId) async {
    _box ??= await Hive.openBox(_boxName);
    await _box!.delete(caseId);
    notifyListeners();
  }

  // ============================================================
  // Math
  // ============================================================
  List<double> _l2Normalize(List<double> v) {
    var norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return v;
    return [for (final x in v) x / norm];
  }

  double _cosine(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    var dot = 0.0, na = 0.0, nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  @override
  void dispose() {
    _detector.close();
    _interpreter?.close();
    super.dispose();
  }
}

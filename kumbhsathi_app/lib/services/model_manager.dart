import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads and tracks on-device model files (Gemma 3n `.task`,
/// MobileFaceNet `.tflite`) under `<appDocs>/models/` (DESIGN.md §7.4).
class ModelManager {
  Dio? _dio;
  Dio get _client => _dio ??= Dio();

  Future<Directory> modelsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> pathFor(String filename) async =>
      '${(await modelsDir()).path}${Platform.pathSeparator}$filename';

  Future<bool> isDownloaded(String filename) async =>
      File(await pathFor(filename)).exists();

  Future<int> sizeOf(String filename) async {
    final f = File(await pathFor(filename));
    return await f.exists() ? f.length() : 0;
  }

  Future<void> delete(String filename) async {
    final f = File(await pathFor(filename));
    if (await f.exists()) await f.delete();
  }

  /// Streams download progress 0.0 → 1.0. Downloads to a `.part` file and
  /// renames on completion so partial downloads never register as ready.
  Stream<double> download({
    required String url,
    required String filename,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async* {
    final target = await pathFor(filename);
    final tmp = '$target.part';

    final controller = _client.download(
      url,
      tmp,
      options: Options(headers: headers, followRedirects: true),
      cancelToken: cancelToken,
      onReceiveProgress: (_, __) {},
    );

    // Poll the growing file while the download future runs so progress can
    // be yielded from this generator without callback re-entry.
    var done = false;
    Object? error;
    int total = -1;

    final future = _client
        .head(url, options: Options(headers: headers))
        .then((r) =>
            total = int.tryParse(r.headers.value('content-length') ?? '') ?? -1)
        .catchError((_) => total = -1);

    controller.then((_) => done = true, onError: (e) {
      error = e;
      done = true;
    });
    await future;

    final tmpFile = File(tmp);
    while (!done) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (total > 0 && await tmpFile.exists()) {
        yield ((await tmpFile.length()) / total).clamp(0.0, 0.99);
      }
    }
    if (error != null) {
      if (await tmpFile.exists()) await tmpFile.delete();
      throw Exception('Model download failed: $error');
    }
    await tmpFile.rename(target);
    yield 1.0;
  }
}

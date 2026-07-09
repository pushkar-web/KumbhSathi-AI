import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

/// Attaches the bearer token and transparently refreshes it on a 401.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required SecureStorage storage,
    required Dio refreshDio,
    this.onAuthFailure,
  })  : _storage = storage,
        _refreshDio = refreshDio;

  final SecureStorage _storage;
  // A bare Dio (no AuthInterceptor) used only to hit /auth/refresh,
  // avoiding an infinite interceptor loop.
  final Dio _refreshDio;
  final Future<void> Function()? onAuthFailure;

  static const _skipAuthPaths = {
    ApiEndpoints.login,
    ApiEndpoints.register,
    ApiEndpoints.refresh,
    ApiEndpoints.otpSend,
    ApiEndpoints.otpVerify,
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_skipAuthPaths.contains(options.path)) {
      final token = await _storage.accessToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['__retried'] == true;
    final isAuthCall = _skipAuthPaths.contains(err.requestOptions.path);

    if (!isUnauthorized || alreadyRetried || isAuthCall) {
      return handler.next(err);
    }

    final refreshToken = await _storage.refreshToken;
    if (refreshToken == null) {
      await onAuthFailure?.call();
      return handler.next(err);
    }

    try {
      final res = await _refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );
      final data = res.data as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      // Replay the original request with the new token.
      final opts = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${data['access_token']}'
        ..extra['__retried'] = true;
      final clone = await _refreshDio.fetch(opts);
      return handler.resolve(clone);
    } catch (_) {
      await _storage.clear();
      await onAuthFailure?.call();
      return handler.next(err);
    }
  }
}

/// Lightweight logging for development builds.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('→ ${options.method} ${options.uri}');
      return true;
    }());
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('✗ ${err.requestOptions.uri} → ${err.response?.statusCode}');
      return true;
    }());
    handler.next(err);
  }
}

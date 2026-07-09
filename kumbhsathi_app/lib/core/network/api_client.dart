import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'api_interceptors.dart';

/// Configured Dio instance for the KumbhSathi backend.
class ApiClient {
  ApiClient({
    required SecureStorage storage,
    Future<void> Function()? onAuthFailure,
  }) {
    _dio = Dio(_baseOptions);
    // Separate, interceptor-free Dio used by the refresh flow.
    final refreshDio = Dio(_baseOptions);

    _dio.interceptors.addAll([
      AuthInterceptor(
        storage: storage,
        refreshDio: refreshDio,
        onAuthFailure: onAuthFailure,
      ),
      LoggingInterceptor(),
    ]);
  }

  late final Dio _dio;
  Dio get dio => _dio;

  static BaseOptions get _baseOptions => BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      );

  // ---- Convenience verbs ----
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);

  Future<Response<T>> post<T>(String path, {Object? data, Map<String, dynamic>? query}) =>
      _dio.post<T>(path, data: data, queryParameters: query);

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path, {Object? data}) =>
      _dio.delete<T>(path, data: data);
}

import 'package:dio/dio.dart';

import '../auth/access_token_provider.dart';
import '../config/network_config.dart';
import '../errors/network_exception.dart';
import '../errors/normalize_dio_exception.dart';
import 'dio_factory.dart';

/// Typed transport only. Feature repositories own DTO conversion and Result.
final class ApiClient {
  ApiClient({
    required NetworkConfig config,
    AccessTokenProvider? tokenProvider,
    HttpClientAdapter? adapter,
    this.diagnosticLogger,
  }) : _dio = createDio(config, tokenProvider, adapter);

  final Dio _dio;

  /// Optional transport diagnostics. Never receives headers or request bodies.
  final void Function(String message)? diagnosticLogger;

  void _log(String message) {
    try {
      diagnosticLogger?.call(message);
    } catch (_) {
      // Diagnostics must never change request behavior.
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    Options? options,
    CancelToken? cancelToken,
  }) => _request<T>(
    'GET',
    path,
    queryParameters: queryParameters,
    requiresAuth: requiresAuth,
    options: options,
    cancelToken: cancelToken,
  );

  Future<Response<T>> post<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    bool requiresAuth = false,
    Options? options,
    CancelToken? cancelToken,
  }) => _request<T>(
    'POST',
    path,
    queryParameters: queryParameters,
    data: data,
    requiresAuth: requiresAuth,
    options: options,
    cancelToken: cancelToken,
  );

  Future<Response<T>> upload<T>(
    String path, {
    required FormData data,
    required void Function(int sent, int total) onSendProgress,
    bool requiresAuth = true,
  }) => _request<T>(
    'POST',
    path,
    data: data,
    requiresAuth: requiresAuth,
    options: Options(contentType: 'multipart/form-data'),
    onSendProgress: onSendProgress,
  );

  Future<Response<T>> put<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    bool requiresAuth = false,
    Options? options,
    CancelToken? cancelToken,
    void Function(Response<Object?>? response)? onErrorResponse,
  }) => _request<T>(
    'PUT',
    path,
    queryParameters: queryParameters,
    data: data,
    requiresAuth: requiresAuth,
    options: options,
    cancelToken: cancelToken,
    onErrorResponse: onErrorResponse,
  );

  Future<Response<T>> patch<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    bool requiresAuth = false,
    Options? options,
    CancelToken? cancelToken,
  }) => _request<T>(
    'PATCH',
    path,
    queryParameters: queryParameters,
    data: data,
    requiresAuth: requiresAuth,
    options: options,
    cancelToken: cancelToken,
  );

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    bool requiresAuth = false,
    Options? options,
    CancelToken? cancelToken,
  }) => _request<T>(
    'DELETE',
    path,
    queryParameters: queryParameters,
    data: data,
    requiresAuth: requiresAuth,
    options: options,
    cancelToken: cancelToken,
  );

  Future<Response<T>> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    required bool requiresAuth,
    void Function(int, int)? onSendProgress,
    Options? options,
    CancelToken? cancelToken,
    void Function(Response<Object?>? response)? onErrorResponse,
  }) async {
    try {
      final uri = Uri.tryParse(path);
      // A configured client must not send its credentials to another origin.
      if (uri == null ||
          uri.hasScheme ||
          uri.hasAuthority ||
          path.startsWith('//') ||
          path.contains('\\')) {
        throw const NetworkException(
          kind: NetworkExceptionKind.unknown,
          message: 'Requests must use a relative API path.',
        );
      }
      final requestOptions = (options ?? Options()).copyWith(
        method: method,
        extra: {...?options?.extra, requiresAuthKey: requiresAuth},
        // Disable implicit redirection/replay, especially for credentials.
        followRedirects: false,
      );
      // Exclude query strings, headers, and bodies (credentials/OTP/tokens).
      final target = Uri.parse(_dio.options.baseUrl);
      _log('[HTTP] $method ${target.origin}${target.path}${uri.path}');
      final response = await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: requestOptions,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      _log('[HTTP] $method ${uri.path} -> ${response.statusCode}');
      return response;
    } on DioException catch (error) {
      _log(
        '[HTTP] $method ${Uri.parse(path).path} -> '
        '${error.type.name}'
        '${error.response == null ? '' : ' (${error.response!.statusCode})'}',
      );
      // Optional inspection must never replace the original transport failure.
      try {
        onErrorResponse?.call(error.response);
      } catch (_) {
        // Diagnostic sinks cannot affect request behavior.
      }
      throw normalizeDioException(error);
    }
  }

  /// Composition owns lifetime. Do not use this client after closing it.
  void close({bool force = false}) => _dio.close(force: force);
}

import 'package:dio/dio.dart';

import '../auth/access_token_provider.dart';
import '../config/network_config.dart';

// Private to the package; callers use ApiClient.requiresAuth instead.
const requiresAuthKey = 'bthere.network.requires_auth';

Dio createDio(
  NetworkConfig config,
  AccessTokenProvider? tokenProvider,
  HttpClientAdapter? adapter,
) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.sendTimeout,
      headers: {'Accept': 'application/json'},
      followRedirects: false,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Transport owns Authorization. Never retain caller-supplied/stale values.
        options.headers = Map.fromEntries(
          options.headers.entries.where(
            (entry) => entry.key.toLowerCase() != 'authorization',
          ),
        );
        if (options.extra[requiresAuthKey] != true || tokenProvider == null) {
          handler.next(options);
          return;
        }
        try {
          final token = await tokenProvider.getAccessToken();
          if (token != null && token.trim().isNotEmpty) {
            if (token.contains(RegExp(r'\s'))) {
              handler.reject(DioException(requestOptions: options));
              return;
            }
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        } catch (_) {
          // Do not retain provider errors that may contain credentials.
          handler.reject(DioException(requestOptions: options));
        }
      },
    ),
  );
  return dio;
}

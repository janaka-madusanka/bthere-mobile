import 'package:flutter/foundation.dart';

final class AppConfig {
  AppConfig({
    required this.apiBaseUrl,
    this.googleServerClientId = '',
    bool allowHttp = kDebugMode,
  }) {
    final uri = Uri.tryParse(apiBaseUrl);
    if (apiBaseUrl.trim() != apiBaseUrl ||
        apiBaseUrl.contains(RegExp(r'\s')) ||
        uri == null ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme) ||
        (!allowHttp && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid BTHERE_API_BASE_URL configuration.');
    }
  }

  final String apiBaseUrl;

  /// Web OAuth client ID matching the backend's Google ID-token audience.
  final String googleServerClientId;

  factory AppConfig.fromEnvironment() => AppConfig(
    apiBaseUrl: const String.fromEnvironment('BTHERE_API_BASE_URL'),
    googleServerClientId: const String.fromEnvironment(
      'BTHERE_GOOGLE_SERVER_CLIENT_ID',
    ),
  );
}

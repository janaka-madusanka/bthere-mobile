import 'package:flutter/foundation.dart';

final class AppConfig {
  AppConfig({
    required this.apiBaseUrl,
    this.googleServerClientId = '',
    this.googleMapsApiKey = '',
    this.nativeGoogleMapsConfigured = false,
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

  final String googleMapsApiKey;
  final bool nativeGoogleMapsConfigured;

  bool get hasGoogleMapsKey {
    final key = googleMapsApiKey.trim();
    return nativeGoogleMapsConfigured ||
        (key.isNotEmpty && key != 'YOUR_GOOGLE_MAPS_API_KEY');
  }

  factory AppConfig.fromEnvironment({
    bool nativeGoogleMapsConfigured = false,
  }) => AppConfig(
    nativeGoogleMapsConfigured: nativeGoogleMapsConfigured,
    apiBaseUrl: const String.fromEnvironment('BTHERE_API_BASE_URL'),
    googleMapsApiKey: const String.fromEnvironment(
      'BTHERE_GOOGLE_MAPS_API_KEY',
    ),
    googleServerClientId: const String.fromEnvironment(
      'BTHERE_GOOGLE_SERVER_CLIENT_ID',
    ),
  );
}

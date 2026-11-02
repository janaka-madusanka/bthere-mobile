import 'package:flutter/foundation.dart';

final class CustomerConfig {
  CustomerConfig({required this.apiBaseUrl, bool allowHttp = kDebugMode}) {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        apiBaseUrl.contains(RegExp(r'\s')) ||
        !{'http', 'https'}.contains(uri.scheme) ||
        (!allowHttp && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.replaceFirst(RegExp(r'/$'), '') != '/api/v1') {
      throw const FormatException('Invalid Customer API configuration.');
    }
  }
  final String apiBaseUrl;
  static CustomerConfig? fromEnvironment() {
    try {
      return CustomerConfig(
        apiBaseUrl: const String.fromEnvironment('BTHERE_API_BASE_URL'),
      );
    } on FormatException {
      return null;
    }
  }
}

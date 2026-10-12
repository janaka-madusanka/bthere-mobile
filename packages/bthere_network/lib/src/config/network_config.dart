/// Environment selection belongs to the application composition layer.
final class NetworkConfig {
  NetworkConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 20),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
  }) {
    final uri = Uri.tryParse(baseUrl);
    if (baseUrl.trim() != baseUrl ||
        baseUrl.contains(RegExp(r'\s')) ||
        uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError(
        'A valid HTTP(S) base URL without credentials is required.',
      );
    }
    if (connectTimeout <= Duration.zero ||
        receiveTimeout <= Duration.zero ||
        sendTimeout <= Duration.zero) {
      throw ArgumentError('Network timeouts must be positive.');
    }
  }

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
}

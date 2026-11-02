import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_config.dart';

final customerConfigProvider = Provider<CustomerConfig?>(
  (ref) => null,
  dependencies: [],
);
final customerClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final customerSessionStorageProvider = Provider<SessionStorage>(
  (ref) => const SecureSessionStorage(store: FlutterSecureKeyValueStore()),
);
final customerAccessTokenProvider = Provider<AccessTokenProvider>(
  (ref) => CustomerAccessTokenProvider(
    ref.watch(customerSessionStorageProvider),
    now: ref.watch(customerClockProvider),
  ),
  dependencies: [customerSessionStorageProvider, customerClockProvider],
);
final customerApiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(customerConfigProvider);
  if (config == null) {
    throw StateError('Customer API configuration is required.');
  }
  final client = ApiClient(
    config: NetworkConfig(baseUrl: config.apiBaseUrl),
    tokenProvider: ref.watch(customerAccessTokenProvider),
  );
  ref.onDispose(() => client.close(force: true));
  return client;
}, dependencies: [customerConfigProvider, customerAccessTokenProvider]);

/// Token supply only: restoration, refresh and entry validation belong to auth.
class CustomerAccessTokenProvider implements AccessTokenProvider {
  CustomerAccessTokenProvider(this.storage, {required this.now});
  final SessionStorage storage;
  final DateTime Function() now;
  @override
  Future<String?> getAccessToken() async {
    final session = await storage.read();
    if (session == null ||
        session.isExpiredAt(now()) ||
        session.user?.roles.contains('CUSTOMER') != true) {
      return null;
    }
    return session.accessToken;
  }
}

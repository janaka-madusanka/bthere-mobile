import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';

final providerSessionApiProvider = Provider<ProviderSessionApi>(
  (ref) {
    final client = ApiClient(config: ref.watch(networkConfigProvider));
    ref.onDispose(() => client.close(force: true));
    return ProviderSessionApi(
      client,
      ref.watch(sessionStorageProvider),
      ref.watch(clockProvider),
    );
  },
  dependencies: [networkConfigProvider, sessionStorageProvider, clockProvider],
);

/// A separate unauthenticated transport prevents recursive token refresh.
class ProviderSessionApi {
  ProviderSessionApi(this.client, this.storage, this.now);
  final ApiClient client;
  final SessionStorage storage;
  final DateTime Function() now;
  Future<AuthSession?>? _refreshing;
  Future<AuthSession?> refresh(AuthSession previous) =>
      _refreshing ??= _refresh(previous).whenComplete(() => _refreshing = null);
  Future<AuthSession?> _refresh(AuthSession previous) async {
    try {
      final response = (await client.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': previous.refreshToken},
      )).data;
      if (response is! Map<String, dynamic> ||
          response['expiresIn'] is! int ||
          (response['expiresIn'] as int) <= 0 ||
          response['tokenType'] != 'Bearer') {
        throw const FormatException('Invalid token response');
      }
      final user = SessionUser.fromJson(response['user']);
      if (!user.roles.contains('SERVICE_PROVIDER') || user.status != 'ACTIVE') {
        throw const FormatException('Invalid provider');
      }
      final next = AuthSession(
        accessToken: response['accessToken'] as String,
        refreshToken: response['refreshToken'] as String,
        tokenType: response['tokenType'] as String,
        expiresAt: now().add(Duration(seconds: response['expiresIn'] as int)),
        user: user,
      );
      // Signing out or changing accounts during refresh must not restore old credentials.
      final current = await storage.read();
      if (current?.refreshToken != previous.refreshToken) return current;
      await storage.write(next);
      return next;
    } on NetworkException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        if ((await storage.read())?.refreshToken == previous.refreshToken) {
          await storage.clear();
        }
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final session = await storage.read();
    if (session != null) {
      await client.post<Object?>(
        '/auth/logout',
        data: {'refreshToken': session.refreshToken},
      );
    }
  }
}

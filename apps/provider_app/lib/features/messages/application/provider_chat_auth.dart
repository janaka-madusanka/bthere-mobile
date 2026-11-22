import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';

import '../../../app/providers/app_providers.dart';
import '../../../core/auth/provider_session_api.dart';

enum ProviderChatStage { authenticated, unauthenticated }

class ProviderChatFailure implements Exception {
  ProviderChatFailure(this.status);
  final int status;
}

final providerChatAuthProvider = Provider<ProviderChatAuth>(
  (ref) => throw StateError('Chat session required'),
);
final providerChatBootstrapProvider = FutureProvider<ProviderChatAuth>(
  (ref) async {
    ref.watch(appSessionStateProvider);
    final auth = ProviderChatAuth(
      ref.watch(apiClientProvider),
      ref.watch(sessionStorageProvider),
      ref.watch(providerSessionApiProvider),
    );
    ref.onDispose(auth.close);
    await auth.restore();
    return auth;
  },
  dependencies: [
    apiClientProvider,
    sessionStorageProvider,
    providerSessionApiProvider,
    appSessionStateProvider,
  ],
);

/// Each request is checked before and after I/O against the original account.
class ProviderChatAuth extends ChangeNotifier {
  ProviderChatAuth(this.client, this.storage, this.sessions);
  final ApiClient client;
  final SessionStorage storage;
  final ProviderSessionApi sessions;
  SessionUser? user;
  int? initialOwner;
  final inboxChanges = ChangeNotifier();
  bool closed = false;
  ProviderChatStage get stage => user == null
      ? ProviderChatStage.unauthenticated
      : ProviderChatStage.authenticated;
  Future<void> restore() async {
    final session = await storage.read();
    if (closed) return;
    final next = session?.user;
    final valid =
        next?.status == 'ACTIVE' && next!.roles.contains('SERVICE_PROVIDER');
    final previous = user?.id;
    if (valid) initialOwner ??= next.id;
    user = valid && next.id == initialOwner ? next : null;
    if (previous != user?.id) notifyListeners();
  }

  Future<Response<Object?>> bookingRequest(
    String method,
    String path, {
    Object? data,
    bool safeRead = false,
  }) async {
    await restore();
    final owner = user?.id;
    if (owner == null) throw ProviderChatFailure(401);
    final options = Options(validateStatus: (_) => true);
    Future<Response<Object?>> perform() => method == 'GET'
        ? client.get<Object?>(path, requiresAuth: true, options: options)
        : client.post<Object?>(
            path,
            requiresAuth: true,
            options: options,
            data: data,
          );
    var response = await perform();
    if (response.statusCode == 401) {
      final current = await storage.read();
      if (current?.user?.id == owner) await sessions.refresh(current!);
      await restore();
      if (closed || user?.id != owner) throw ProviderChatFailure(401);
      if (safeRead) response = await perform();
    }
    await restore();
    if (closed || user?.id != owner || response.statusCode == 401) {
      throw ProviderChatFailure(401);
    }
    return response;
  }

  void refreshInboxes() {
    if (!closed) inboxChanges.notifyListeners();
  }

  void close() {
    closed = true;
    user = null;
    notifyListeners();
    inboxChanges.dispose();
    dispose();
  }
}

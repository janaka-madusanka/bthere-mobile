import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../core/session/app_session_state.dart';

/// Read only the confirmed account metadata from the existing secure session.
final providerAccountProvider = FutureProvider.autoDispose<SessionUser?>(
  (ref) async {
    final state = await ref.watch(appSessionStateProvider.future);
    if (!ref.mounted || state != AppSessionState.authenticated) return null;
    final session = await ref.watch(sessionStorageProvider).read();
    if (!ref.mounted ||
        session == null ||
        session.isExpiredAt(ref.read(clockProvider)())) {
      return null;
    }
    return session.user;
  },
  dependencies: [
    appSessionStateProvider,
    sessionStorageProvider,
    clockProvider,
  ],
);

class SignOutState {
  const SignOutState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

final providerSignOutProvider =
    NotifierProvider<ProviderSignOutController, SignOutState>(
      ProviderSignOutController.new,
      dependencies: [sessionStorageProvider, appSessionStateProvider],
    );

class ProviderSignOutController extends Notifier<SignOutState> {
  @override
  SignOutState build() => const SignOutState();

  Future<void> signOut() async {
    if (state.busy) return;
    state = const SignOutState(busy: true);
    try {
      await ref.read(sessionStorageProvider).clear();
      if (!ref.mounted) return;
      // Redirect only after secure credentials have actually been removed.
      ref.invalidate(appSessionStateProvider);
      state = const SignOutState();
    } catch (_) {
      if (ref.mounted) {
        state = const SignOutState(
          error: 'Unable to sign out. Please try again.',
        );
      }
    }
  }
}

import 'package:bthere_session/bthere_session.dart';

enum AppSessionState {
  checking,
  unauthenticated,
  authenticated,
  configurationFailure,
  restorationFailure,
}

/// Local credential restoration only; this does not prove backend account state.
Future<AppSessionState> restoreAppSession(
  SessionStorage storage, {
  required DateTime Function() now,
}) async {
  try {
    final session = await storage.read();
    if (session == null || session.isExpiredAt(now())) {
      return AppSessionState.unauthenticated;
    }
    return AppSessionState.authenticated;
  } catch (_) {
    // Do not expose potentially sensitive plugin errors to widgets/logs.
    return AppSessionState.restorationFailure;
  }
}

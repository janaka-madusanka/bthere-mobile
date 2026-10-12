import 'dart:async';

import 'package:provider_app/features/auth/domain/google_identity_provider.dart';

class FakeGoogleIdentityProvider implements GoogleIdentityProvider {
  int calls = 0;
  String? token = 'synthetic-google-id';
  Object? error;
  Completer<String?>? pending;

  @override
  Future<String?> requestIdToken() async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? token : await pending!.future;
  }
}

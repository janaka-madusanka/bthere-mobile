import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:provider_app/core/auth/provider_session_api.dart';

import 'fake_session_storage.dart';

/// An explicitly rejected synthetic refresh, without network access.
class RejectedProviderSessionApi extends ProviderSessionApi {
  RejectedProviderSessionApi()
    : super(
        ApiClient(
          config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        ),
        FakeSessionStorage(),
        () => testNow,
      );
  @override
  Future<AuthSession?> refresh(AuthSession previous) async => null;
}

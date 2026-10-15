import 'dart:async';

import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/core/auth/provider_session_api.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/onboarding/profile/data/provider_profile_request.dart';
import 'package:provider_app/features/onboarding/profile/domain/provider_profile_input.dart';

import 'registration_api_test.dart' show RegistrationAdapter;
import 'support/fake_session_storage.dart';

class PendingRefreshAdapter extends RegistrationAdapter {
  final pending = Completer<void>();
  @override
  Future<ResponseBody> fetch(options, requestStream, cancelFuture) async {
    await pending.future;
    return super.fetch(options, requestStream, cancelFuture);
  }
}

Map<String, dynamic> refreshed() => {
  'accessToken': 'new-access',
  'refreshToken': 'new-refresh',
  'tokenType': 'Bearer',
  'expiresIn': 900,
  'user': {
    'id': 25,
    'username': 'provider',
    'status': 'ACTIVE',
    'roles': ['SERVICE_PROVIDER'],
  },
};
void main() {
  test('expired access refreshes once, rotates both tokens, and stores provider account', () async {
    final adapter = PendingRefreshAdapter()
      ..responses['/auth/refresh'] = refreshed();
    final storage = FakeSessionStorage()..session = testSession(expired: true);
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      adapter: adapter,
    );
    addTearDown(() => client.close(force: true));
    final api = ProviderSessionApi(client, storage, () => testNow);
    final provider = SessionAccessTokenProvider(
      storage,
      now: () => testNow,
      refreshSession: api.refresh,
    );
    final a = provider.getAccessToken(), b = provider.getAccessToken();
    adapter.pending.complete();
    expect(await a, 'new-access');
    expect(await b, 'new-access');
    expect(adapter.requests.length, 1);
    expect(adapter.requests.single.data, {'refreshToken': 'synthetic-refresh'});
    expect(storage.session!.refreshToken, 'new-refresh');
    expect(storage.session!.user!.id, 25);
    expect(
      storage.session!.expiresAt,
      testNow.add(const Duration(seconds: 900)),
    );
  });
  test('signing out during refresh cannot restore the old account', () async {
    final adapter = PendingRefreshAdapter()
      ..responses['/auth/refresh'] = refreshed();
    final storage = FakeSessionStorage()..session = testSession(expired: true);
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      adapter: adapter,
    );
    addTearDown(() => client.close(force: true));
    final api = ProviderSessionApi(client, storage, () => testNow),
        previous = storage.session!;
    final future = api.refresh(previous);
    await storage.clear();
    adapter.pending.complete();
    expect(await future, isNull);
    expect(storage.session, isNull);
    expect(storage.writes, 0);
  });
  test(
    'logout uses the refresh token body without an access token header',
    () async {
      final adapter = RegistrationAdapter();
      final storage = FakeSessionStorage()..session = testSession();
      final client = ApiClient(
        config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        adapter: adapter,
      );
      addTearDown(() => client.close(force: true));
      await ProviderSessionApi(client, storage, () => testNow).logout();
      expect(adapter.requests.single.path, '/auth/logout');
      expect(adapter.requests.single.data, {
        'refreshToken': 'synthetic-refresh',
      });
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );
  test(
    'profile editing preserves optional saved identity and photo values',
    () {
      final body = serializeProviderProfile(
        ProviderProfileInput(
          marketId: 1,
          firstName: 'Jane',
          lastName: 'Doe',
          dateOfBirth: DateTime(1990),
          gender: ProviderGender.female,
          availabilityStatus: ProviderAvailability.available,
          nicNumber: '200012345678',
          passportNumber: 'N123456',
          profilePhoto: 'https://example.invalid/photo.jpg',
        ),
      );
      expect(body['nicNumber'], '200012345678');
      expect(body['passportNumber'], 'N123456');
      expect(body['profilePhoto'], 'https://example.invalid/photo.jpg');
    },
  );
}

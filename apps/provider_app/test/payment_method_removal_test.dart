import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/wallet/data/wallet_repository.dart';
import 'package:provider_app/features/wallet/domain/wallet_models.dart';

import 'registration_api_test.dart' show RegistrationAdapter;
import 'support/fake_session_storage.dart';

void main() {
  test(
    'saved method removal is an authenticated bodyless DELETE accepting 204',
    () async {
      final adapter = RegistrationAdapter()
        ..handler = (request) => ResponseBody.fromString('', 204);
      final client = ApiClient(
        config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        adapter: adapter,
        tokenProvider: SessionAccessTokenProvider(
          FakeSessionStorage()..session = testSession(),
          now: () => testNow,
        ),
      );
      addTearDown(() => client.close(force: true));
      await WalletRepository(client).removeMethod(5);
      expect(adapter.requests.single.path, '/me/payment-methods/5');
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.data, isNull);
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer synthetic-access',
      );
    },
  );
  test('pending payment conflict explains when removal can be retried', () async {
    final adapter = RegistrationAdapter()
      ..handler = (request) => ResponseBody.fromString(
        '{"status":409,"detail":"Payment method is used by a pending payment"}',
        409,
        headers: {
          Headers.contentTypeHeader: ['application/problem+json'],
        },
      );
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      adapter: adapter,
    );
    addTearDown(() => client.close(force: true));
    await expectLater(
      WalletRepository(client).removeMethod(5),
      throwsA(
        isA<NetworkException>()
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.message, 'detail', contains('pending payment')),
      ),
    );
  });
  test(
    'brand uses explicit server field, settings do not prove booking payment',
    () {
      final card = WalletMethod.fromJson({
        'methodId': 5,
        'type': 'CARD',
        'displayLabel': 'VISA 4242',
        'status': 'VERIFIED_MOCK',
      });
      expect(card.brand, isNull);
      final settings = WalletCapabilities.fromJson({
        'provider': 'MOCK',
        'testMode': true,
        'capabilities': {'cardLinking': true},
      });
      expect(settings.provider, 'MOCK');
      expect(settings.testMode, isTrue);
      expect(settings.cardLinking, isTrue);
    },
  );
}

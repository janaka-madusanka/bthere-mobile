import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/core/session/app_session_state.dart';

import 'support/fake_session_storage.dart';
import 'support/fake_provider_session_api.dart';

import 'package:provider_app/core/auth/provider_session_api.dart';

void main() {
  test('accepts HTTPS absolute configuration', () {
    expect(
      AppConfig(
        apiBaseUrl: 'https://example.invalid/api/v1',
        allowHttp: false,
      ).apiBaseUrl,
      'https://example.invalid/api/v1',
    );
  });
  test('allows HTTP only when development policy permits it', () {
    expect(
      AppConfig(
        apiBaseUrl: 'http://localhost:8080/api/v1',
        allowHttp: true,
      ).apiBaseUrl,
      startsWith('http:'),
    );
    expect(
      () => AppConfig(
        apiBaseUrl: 'http://localhost:8080/api/v1',
        allowHttp: false,
      ),
      throwsFormatException,
    );
  });
  final invalid = [
    '',
    ' ',
    'not a url',
    '/api/v1',
    'https://',
    'ftp://example.invalid',
    'https://user:password@example.invalid',
    'https://example.invalid?key=value',
    'https://example.invalid/#fragment',
  ];
  for (var index = 0; index < invalid.length; index++) {
    test('rejects invalid configuration case $index safely', () {
      expect(
        () => AppConfig(apiBaseUrl: invalid[index]),
        throwsFormatException,
      );
    });
  }
  test('bridge returns null without stored session', () async {
    final store = FakeSessionStorage();
    expect(
      await SessionAccessTokenProvider(
        store,
        now: () => testNow,
      ).getAccessToken(),
      isNull,
    );
    expect(store.reads, 1);
  });
  test('bridge returns access token only, rechecking each call', () async {
    final store = FakeSessionStorage()..session = testSession();
    var time = testNow;
    final bridge = SessionAccessTokenProvider(store, now: () => time);
    final token = await bridge.getAccessToken();
    expect(token == store.session!.accessToken, isTrue);
    expect(token == store.session!.refreshToken, isFalse);
    time = store.session!.expiresAt;
    expect(await bridge.getAccessToken(), isNull);
    expect(store.reads, 2);
    expect(store.clears, 0);
    expect(store.session, isNotNull);
  });
  test('bridge refuses expired credentials and keeps them intact', () async {
    final store = FakeSessionStorage()..session = testSession(expired: true);
    expect(
      await SessionAccessTokenProvider(
        store,
        now: () => testNow,
      ).getAccessToken(),
      isNull,
    );
    expect(store.clears, 0);
    expect(store.session, isNotNull);
  });
  test('bridge read failures propagate for network normalization', () async {
    final store = FakeSessionStorage()..failRead = true;
    await expectLater(
      SessionAccessTokenProvider(store).getAccessToken(),
      throwsStateError,
    );
  });
  for (final kind in ['missing', 'valid', 'expired', 'failed']) {
    test('startup restoration handles $kind with one local read', () async {
      final store = FakeSessionStorage()
        ..session = kind == 'valid'
            ? testSession()
            : kind == 'expired'
            ? testSession(expired: true)
            : null
        ..failRead = kind == 'failed';
      final container = ProviderContainer(
        overrides: [
          providerSessionApiProvider.overrideWithValue(
            RejectedProviderSessionApi(),
          ),
          appConfigProvider.overrideWithValue(
            AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
          ),
          sessionStorageProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => testNow),
          apiClientProvider.overrideWith(
            (ref) => throw StateError(
              'Startup must not construct HTTP dependencies',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final expected = kind == 'valid'
          ? AppSessionState.authenticated
          : kind == 'failed'
          ? AppSessionState.restorationFailure
          : AppSessionState.unauthenticated;
      expect(await container.read(appSessionStateProvider.future), expected);
      expect(await container.read(appSessionStateProvider.future), expected);
      expect(store.reads, 1);
      expect(store.writes, 0);
      expect(store.clears, 0);
      if (kind == 'expired') expect(store.session, isNotNull);
    });
  }
  test('missing configuration does not construct storage/network', () async {
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWith(
          (ref) => throw StateError('Must not read storage'),
        ),
        apiClientProvider.overrideWith(
          (ref) => throw StateError('Must not create network'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(appSessionStateProvider.future),
      AppSessionState.configurationFailure,
    );
  });
  test('composition constructs actual repository/client without requests', () {
    final store = FakeSessionStorage();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
        ),
        sessionStorageProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => testNow),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(providerAuthRepositoryProvider),
      isA<ProviderAuthRepositoryImpl>(),
    );
    expect(container.read(apiClientProvider), isA<ApiClient>());
    expect(
      container.read(networkConfigProvider).baseUrl,
      'https://example.invalid/api/v1',
    );
    expect(store.reads, 0);
    expect(store.writes, 0);
  });
}

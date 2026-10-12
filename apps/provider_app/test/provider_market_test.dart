import 'support/completed_entry_gate.dart';

import 'package:provider_app/features/onboarding/application/provider_entry_gate.dart';

import 'support/fake_configured_service.dart';

import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/markets/application/provider_market_controller.dart';
import 'package:provider_app/features/onboarding/markets/data/provider_market_remote_data_source.dart';
import 'package:provider_app/features/onboarding/markets/data/provider_market_repository_impl.dart';
import 'package:provider_app/features/onboarding/markets/data/provider_market_response.dart';
import 'package:provider_app/features/onboarding/markets/domain/provider_market.dart';
import 'package:provider_app/features/onboarding/profile/application/provider_profile_controller.dart';
import 'package:provider_app/features/onboarding/profile/data/provider_profile_request.dart';

import 'support/fake_completion_repository.dart';
import 'support/fake_market_repository.dart';
import 'support/fake_profile_repository.dart';
import 'support/fake_session_storage.dart';
import 'provider_profile_test.dart' show input, ProfileAdapter;

void main() {
  test(
    'immutable market list parses all documented fields and ignores timestamps',
    () {
      final markets = parseActiveProviderMarkets([marketJson()]);
      final market = markets.single;
      expect(market.id, 7);
      expect(market.name, 'Test market');
      expect(market.countryCode, 'LK');
      expect(market.currencyCode, 'LKR');
      expect(market.timezone, 'Asia/Colombo');
      expect(market.locale, 'en-LK');
      expect(market.phoneCode, '+94');
      expect(market.status, 'ACTIVE');
      expect(() => markets.clear(), throwsUnsupportedError);
    },
  );
  test('empty and inactive lists produce no selectable markets', () {
    expect(parseActiveProviderMarkets([]), isEmpty);
    expect(
      parseActiveProviderMarkets([
        marketJson(status: 'INACTIVE'),
        marketJson(id: 2, status: 'FUTURE_STATUS'),
      ]),
      isEmpty,
    );
    expect(
      parseActiveProviderMarkets([
        marketJson(status: 'INACTIVE'),
        marketJson(id: 42, name: 'Other market'),
      ]).single.id,
      42,
    );
  });
  for (final id in [null, 0, -1, 1.5, '1', true]) {
    test('malformed market ID $id is rejected', () {
      expect(
        () => parseActiveProviderMarkets([marketJson()..['id'] = id]),
        throwsFormatException,
      );
    });
  }
  test('duplicate IDs are rejected safely before dropdown creation', () {
    expect(
      () => parseActiveProviderMarkets([marketJson(), marketJson()]),
      throwsFormatException,
    );
  });
  for (final field in [
    'name',
    'countryCode',
    'currencyCode',
    'timezone',
    'locale',
    'phoneCode',
    'status',
  ]) {
    test('missing or malformed $field fails defensive parsing', () {
      for (final value in [null, '', '  ', 7]) {
        expect(
          () => parseActiveProviderMarkets([marketJson()..[field] = value]),
          throwsFormatException,
        );
      }
    });
  }
  test('non-array and invalid market entries fail safely', () {
    for (final value in [
      null,
      {},
      'private',
      [null],
      [1],
    ]) {
      expect(() => parseActiveProviderMarkets(value), throwsFormatException);
    }
  });
  test('required profile market IDs must be positive and serialize as IDs', () {
    expect(input(marketId: 0).validationMessage(testNow), isNotNull);
    expect(input(marketId: -1).validationMessage(testNow), isNotNull);
    expect(serializeProviderProfile(input(marketId: 42))['marketId'], 42);
    expect(serializeProviderProfile(input(marketId: 42)).length, 10);
  });

  late ProfileAdapter adapter;
  late ApiClient client;
  late FakeSessionStorage storage;
  late ProviderMarketRepositoryImpl repository;
  setUp(() {
    adapter = ProfileAdapter()..body = [marketJson()];
    storage = FakeSessionStorage()..session = testSession();
    client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(storage, now: () => testNow),
      adapter: adapter,
    );
    repository = ProviderMarketRepositoryImpl(
      ProviderMarketRemoteDataSource(client),
    );
  });
  tearDown(() => client.close(force: true));
  test(
    'GET markets opts into auth and uses the existing token bridge',
    () async {
      final result =
          await repository.loadActiveMarkets() as Success<List<ProviderMarket>>;
      expect(result.value.single.id, 7);
      expect(adapter.request!.method, 'GET');
      expect(adapter.request!.path, '/markets');
      expect(adapter.request!.extra['bthere.network.requires_auth'], isTrue);
      expect(
        adapter.request!.headers['Authorization'],
        'Bearer synthetic-access',
      );
      expect(storage.reads, 1);
      expect(storage.writes, 0);
      expect(storage.clears, 0);
    },
  );
  test(
    'repository supports empty response and safely rejects malformed IDs',
    () async {
      adapter.body = [];
      expect(
        (await repository.loadActiveMarkets() as Success<List<ProviderMarket>>)
            .value,
        isEmpty,
      );
      adapter.body = [marketJson()..['id'] = 'private-invalid'];
      final result =
          await repository.loadActiveMarkets() as Failure<List<ProviderMarket>>;
      expect(result.failure.code, 'MARKETS_INVALID_RESPONSE');
      expect(result.failure.message, isNot(contains('private')));
    },
  );
  for (final status in [401, 500]) {
    test(
      'market HTTP $status maps safe failure without session mutation',
      () async {
        adapter.status = status;
        adapter.body = {'message': 'private token trace'};
        final result =
            await repository.loadActiveMarkets()
                as Failure<List<ProviderMarket>>;
        expect(result.failure.message, isNot(contains('private')));
        expect(result.failure.cause, isNull);
        expect(storage.writes, 0);
        expect(storage.clears, 0);
      },
    );
  }
  test('market transport error maps through network failure model', () async {
    adapter.connectionFailure = true;
    final result =
        await repository.loadActiveMarkets() as Failure<List<ProviderMarket>>;
    expect(result.failure.code, startsWith('NETWORK_'));
    expect(result.failure.message, isNot(contains('private')));
  });

  ProviderContainer scope(
    FakeMarketRepository markets,
    FakeProfileRepository profile, {
    bool authenticated = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        providerEntryGateProvider.overrideWith(CompletedEntryGate.new),
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
        ),
        sessionStorageProvider.overrideWithValue(
          FakeSessionStorage()..session = authenticated ? testSession() : null,
        ),
        clockProvider.overrideWithValue(() => testNow),
        providerMarketRepositoryProvider.overrideWithValue(markets),
        providerProfileRepositoryProvider.overrideWithValue(profile),
        providerServiceRepositoryProvider.overrideWithValue(
          configuredServiceRepository(),
        ),
        providerSchemaRepositoryProvider.overrideWithValue(
          configuredSchemaRepository(),
        ),
        providerOptionsRepositoryProvider.overrideWithValue(
          configuredOptionsRepository(),
        ),
        providerCompletionRepositoryProvider.overrideWithValue(
          FakeCompletionRepository()
            ..result = Success(
              parseProviderCompletion(completionJson(step: 'COMPLETE_PROFILE')),
            ),
        ),
        apiClientProvider.overrideWith(
          (ref) => throw StateError('No live backend permitted'),
        ),
        googleIdentityProvider.overrideWith(
          (ref) => throw StateError('Google stays dormant'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('unauthenticated market controller makes no request', () async {
    final markets = FakeMarketRepository();
    final container = scope(
      markets,
      FakeProfileRepository(),
      authenticated: false,
    );
    container.listen(providerMarketControllerProvider, (_, _) {});
    expect(
      await container.read(providerMarketControllerProvider.future),
      isA<Failure<List<ProviderMarket>>>(),
    );
    expect(markets.calls, 0);
  });
  test('market reload blocks duplicate reloads while pending', () async {
    final markets = FakeMarketRepository();
    final container = scope(markets, FakeProfileRepository());
    container.listen(providerMarketControllerProvider, (_, _) {});
    await container.read(providerMarketControllerProvider.future);
    markets.pending = Completer<Result<List<ProviderMarket>>>();
    container.read(providerMarketControllerProvider.notifier).reload();
    final future = container.read(providerMarketControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    container.read(providerMarketControllerProvider.notifier).reload();
    expect(markets.calls, 2);
    markets.pending!.complete(const Success([]));
    await future;
  });
  for (final scenario in [
    'loading',
    'failure',
    'empty',
    'inactive',
    'unlisted',
  ]) {
    test(
      'profile controller prevents submission with $scenario market state',
      () async {
        final markets = FakeMarketRepository();
        switch (scenario) {
          case 'loading':
            markets.pending = Completer<Result<List<ProviderMarket>>>();
          case 'failure':
            markets.result = const Failure(AppFailure(message: 'Unavailable'));
          case 'empty':
            markets.result = const Success([]);
          case 'inactive':
            markets.result = const Success([
              ProviderMarket(
                id: 7,
                name: 'Inactive',
                countryCode: 'LK',
                currencyCode: 'LKR',
                timezone: 'Asia/Colombo',
                locale: 'en-LK',
                phoneCode: '+94',
                status: 'INACTIVE',
              ),
            ]);
          case 'unlisted':
            markets.result = Success(
              parseActiveProviderMarkets([marketJson(id: 42)]),
            );
        }
        final profile = FakeProfileRepository();
        final container = scope(markets, profile);
        container.listen(providerMarketControllerProvider, (_, _) {});
        container.listen(providerProfileControllerProvider, (_, _) {});
        if (scenario != 'loading') {
          await container.read(providerMarketControllerProvider.future);
        }
        await container
            .read(providerProfileControllerProvider.notifier)
            .submit(input());
        expect(profile.calls, 0);
        expect(
          container.read(providerProfileControllerProvider).failure!.code,
          'PROFILE_MARKET_REQUIRED',
        );
        markets.pending?.complete(const Success([]));
      },
    );
  }
  test('unexpected market exception becomes safe controller failure', () async {
    final markets = FakeMarketRepository()..throwOnLoad = true;
    final container = scope(markets, FakeProfileRepository());
    container.listen(providerMarketControllerProvider, (_, _) {});
    final result = await container.read(
      providerMarketControllerProvider.future,
    ) as Failure<List<ProviderMarket>>;
    expect(result.failure.message, isNot(contains('private')));
  });

  Finder textField(String label) => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is BThereTextField && widget.label == label,
    ),
    matching: find.byType(TextFormField),
  );
  Finder continueButton() => find.widgetWithText(BThereButton, 'Continue');
  Future<ProviderContainer> pumpMarkets(
    WidgetTester tester,
    FakeMarketRepository markets, {
    FakeProfileRepository? profile,
    bool pending = false,
  }) async {
    final container = scope(markets, profile ?? FakeProfileRepository());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BThereProviderApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    container.read(appRouterProvider).go('/services/3/setup/profile');
    if (pending) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    } else {
      await tester.pumpAndSettle();
    }
    return container;
  }

  Future<void> selectMarket(WidgetTester tester, String name) async {
    final market = find.byKey(const ValueKey('profile-market'));
    await tester.ensureVisible(market);
    await tester.tap(market);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> fillOtherFields(WidgetTester tester) async {
    await tester.enterText(textField('First name'), 'Jane');
    await tester.enterText(textField('Last name'), 'Doe');
    final date = find.byKey(const ValueKey('profile-date-of-birth'));
    await tester.ensureVisible(date);
    await tester.tap(date);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final gender = find.byKey(const ValueKey('profile-gender'));
    await tester.ensureVisible(gender);
    await tester.tap(gender);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();
  }

  testWidgets('market loading keeps text inputs usable and Continue disabled', (
    tester,
  ) async {
    final markets = FakeMarketRepository()
      ..pending = Completer<Result<List<ProviderMarket>>>();
    final profile = FakeProfileRepository();
    await pumpMarkets(tester, markets, profile: profile, pending: true);
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Loading markets…'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(textField('First name')).enabled,
      isTrue,
    );
    await tester.enterText(textField('First name'), 'Typed while loading');
    expect(tester.widget<BThereButton>(continueButton()).onPressed, isNull);
    expect(profile.calls, 0);
    markets.pending!.complete(
      Success(parseActiveProviderMarkets([marketJson()])),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(textField('First name')).controller!.text,
      'Typed while loading',
    );
    expect(tester.widget<BThereButton>(continueButton()).onPressed, isNull);
  });
  testWidgets('one active market still requires explicit selection', (
    tester,
  ) async {
    await pumpMarkets(tester, FakeMarketRepository());
    final selector = tester.widget<BThereSelectorField<int>>(
      find.byKey(const ValueKey('profile-market')),
    );
    expect(selector.initialValue, isNull);
    expect(tester.widget<BThereButton>(continueButton()).onPressed, isNull);
    await selectMarket(tester, 'Test market');
    expect(find.text('Test market'), findsOneWidget);
    expect(tester.widget<BThereButton>(continueButton()).onPressed, isNotNull);
  });
  testWidgets(
    'multiple markets display names and submit the selected numeric ID',
    (tester) async {
      final markets = FakeMarketRepository()
        ..result = Success(
          parseActiveProviderMarkets([
            marketJson(),
            marketJson(id: 42, name: 'Second market'),
            marketJson(id: 3, name: 'Hidden market', status: 'INACTIVE'),
          ]),
        );
      final profile = FakeProfileRepository()
        ..result = const Failure(AppFailure(message: 'Synthetic safe failure'));
      await pumpMarkets(tester, markets, profile: profile);
      expect(
        tester
            .widget<BThereSelectorField<int>>(
              find.byKey(const ValueKey('profile-market')),
            )
            .initialValue,
        isNull,
      );
      await fillOtherFields(tester);
      expect(tester.widget<BThereButton>(continueButton()).onPressed, isNull);
      await selectMarket(tester, 'Second market');
      expect(find.text('Second market'), findsOneWidget);
      expect(find.text('Hidden market'), findsNothing);
      await tester.ensureVisible(continueButton());
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(profile.calls, 1);
      expect(profile.input!.marketId, 42);
      expect(serializeProviderProfile(profile.input!)['marketId'], 42);
    },
  );
  testWidgets('market failure and repeated Retry preserve all profile inputs', (
    tester,
  ) async {
    final markets = FakeMarketRepository()
      ..result = const Failure(AppFailure(message: 'Unable to connect.'));
    final container = await pumpMarkets(tester, markets);
    await fillOtherFields(tester);
    await tester.enterText(textField('Bio (optional)'), 'My bio');
    final retry = find.widgetWithText(BThereButton, 'Retry markets');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(markets.calls, 2);
    expect(find.text('Unable to connect.'), findsOneWidget);
    expect(tester.widget<BThereButton>(continueButton()).onPressed, isNull);
    markets.result = Success(parseActiveProviderMarkets([marketJson()]));
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(markets.calls, 3);
    for (final entry in {
      'First name': 'Jane',
      'Last name': 'Doe',
      'Bio (optional)': 'My bio',
    }.entries) {
      expect(
        tester.widget<TextFormField>(textField(entry.key)).controller!.text,
        entry.value,
      );
    }
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('profile-date-of-birth')),
          )
          .controller!
          .text,
      isNotEmpty,
    );
    expect(find.text('Male'), findsOneWidget);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/services/3/setup/profile',
    );
  });
  testWidgets(
    'empty markets clearly explain unavailable state and prevent submission',
    (tester) async {
      final markets = FakeMarketRepository()..result = const Success([]);
      final profile = FakeProfileRepository();
      await pumpMarkets(tester, markets, profile: profile);
      expect(find.text('No markets are currently available.'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-market')), findsNothing);
      expect(tester.widget<BThereButton>(continueButton()).onPressed, isNull);
      expect(
        tester.widget<TextFormField>(textField('First name')).enabled,
        isTrue,
      );
      expect(profile.calls, 0);
    },
  );
  testWidgets(
    'market refresh preserves a valid selection but clears a removed choice',
    (tester) async {
      final markets = FakeMarketRepository();
      final container = await pumpMarkets(tester, markets);
      await selectMarket(tester, 'Test market');
      container.read(providerMarketControllerProvider.notifier).reload();
      await tester.pumpAndSettle();
      expect(find.text('Test market'), findsOneWidget);
      expect(
        tester.widget<BThereButton>(continueButton()).onPressed,
        isNotNull,
      );
      markets.result = Success(
        parseActiveProviderMarkets([
          marketJson(id: 42, name: 'Replacement market'),
        ]),
      );
      container.read(providerMarketControllerProvider.notifier).reload();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BThereSelectorField<int>>(
              find.byKey(const ValueKey('profile-market')),
            )
            .initialValue,
        isNull,
      );
      expect(tester.widget<BThereButton>(continueButton()).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/core/session/app_session_state.dart';
import 'package:provider_app/features/wallet/application/wallet_controller.dart';
import 'package:provider_app/features/wallet/data/wallet_repository.dart';
import 'package:provider_app/features/wallet/domain/wallet_models.dart';
import 'package:provider_app/features/wallet/presentation/wallet_screen.dart';

import 'registration_api_test.dart' show RegistrationAdapter;
import 'service_first_test.dart' show ServiceFixture, pump;
import 'support/fake_session_storage.dart';
import 'support/fake_wallet_repository.dart';

AuthSession walletSession() => AuthSession(
  accessToken: 'synthetic-access',
  refreshToken: 'synthetic-refresh',
  tokenType: 'Bearer',
  expiresAt: testNow.add(const Duration(hours: 1)),
  user: SessionUser(
    id: 25,
    username: 'test.provider',
    status: 'ACTIVE',
    roles: ['SERVICE_PROVIDER'],
  ),
);

Future<void> walletScrollTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    150,
    scrollable: find
        .descendant(
          of: find.byType(WalletScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('wallet reference layout with server-backed test data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    for (final item in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'Nunito': 'assets/fonts/Nunito.ttf',
    }.entries) {
      await (FontLoader(item.key)..addFont(rootBundle.load(item.value))).load();
    }
    await pump(tester, ServiceFixture(), route: AppRoutes.wallet);
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/provider_wallet.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unfunded wallet shows compact banner and its top-up opens the existing flow',
    (tester) async {
      final fixture = ServiceFixture()..storage.session = walletSession();
      final repository = fixture.container.read(
        walletRepositoryProvider,
      ) as FakeWalletRepository;
      final original = walletSnapshot(empty: true);
      repository.snapshot = WalletSnapshot(
        capabilities: original.capabilities,
        balance: WalletBalance.fromJson(
          walletBalanceJson(available: '0', mode: 'UNFUNDED'),
        ),
        methods: original.methods,
        history: original.history,
        balanced: true,
      );
      await pump(tester, fixture, route: AppRoutes.wallet);
      final banner = find.byKey(const ValueKey('wallet-balance'));
      expect(
        find.descendant(of: banner, matching: find.text('Top Up Wallet')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: banner,
          matching: find.text('Pending (in progress)'),
        ),
        findsNothing,
      );
      expect(find.text('Top Up Wallet'), findsOneWidget);
      await tester.tap(
        find.descendant(of: banner, matching: find.text('Top Up Wallet')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('wallet-payment-amount')),
        findsOneWidget,
      );
      expect(repository.creates, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('top-up entry opens even when the server disables payments', (
    tester,
  ) async {
    final fixture = ServiceFixture()..storage.session = walletSession();
    final repository = fixture.container.read(
      walletRepositoryProvider,
    ) as FakeWalletRepository;
    final original = walletSnapshot(enabled: false, empty: true);
    repository.snapshot = WalletSnapshot(
      capabilities: original.capabilities,
      balance: WalletBalance.fromJson(
        walletBalanceJson(available: '0', mode: 'UNFUNDED'),
      ),
      methods: [],
      history: original.history,
      balanced: true,
    );
    await pump(tester, fixture, route: AppRoutes.wallet);
    await tester.tap(find.text('Top Up Wallet'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-payment-amount')), findsOneWidget);
    expect(
      find.textContaining('Top-ups are currently disabled'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create top-up'),
          )
          .onPressed,
      isNull,
    );
    expect(repository.creates, 0);
  });

  testWidgets('wallet error fills the page and retry recovers live content', (
    tester,
  ) async {
    final fixture = ServiceFixture();
    final repository = fixture.container.read(
      walletRepositoryProvider,
    ) as FakeWalletRepository;
    repository.loadError = const FormatException('Invalid wallet response');
    await pump(tester, fixture, route: AppRoutes.wallet);
    final panel = find
        .ancestor(
          of: find.text('Unable to load wallet'),
          matching: find.byType(Material),
        )
        .first;
    expect(
      tester.getSize(panel).width,
      tester.getSize(find.byType(WalletScreen)).width,
    );
    expect(find.text('Retry').hitTestable(), findsOneWidget);
    repository.loadError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Available Balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'money preserves maximum decimal precision without double arithmetic',
    () {
      final money = WalletMoney.parse('99999999999999.99');
      expect(money.minor.toString(), '9999999999999999');
      expect(money.decimal, '99999999999999.99');
      expect(money.formatted, '99,999,999,999,999.99');
      expect(money.validPayment, isTrue);
      expect(WalletMoney.parse('100000000000000').validPayment, isFalse);
      expect(() => WalletMoney.parse('10.001'), throwsFormatException);
      expect(() => WalletMoney.parse('NaN'), throwsFormatException);
      final decoded = walletObject(
        decodeWalletJson(
          '{"walletId":10,"available":99999999999999.99,"pending":0,"reserved":0}',
        ),
      );
      expect(WalletMoney.parse(decoded['available']).minor, money.minor);
      expect(decoded['walletId'], 10);
    },
  );

  test(
    'server decimal scale and exponent notation preserve exact hundredths',
    () {
      for (final entry in {
        '0.0000': '0.00',
        '12.3400': '12.34',
        '0E-8': '0.00',
        '1E+3': '1000.00',
        '-1.234E1': '-12.34',
        '99999999999999.9900': '99999999999999.99',
      }.entries) {
        expect(WalletMoney.parse(entry.key).decimal, entry.value);
      }
      expect(() => WalletMoney.parse('12.3401'), throwsFormatException);
      expect(() => WalletMoney.parse('1E-3'), throwsFormatException);
      final json = walletObject(
        decodeWalletJson('{"available":9999999999999999e-2}'),
      );
      expect(WalletMoney.parse(json['available']).decimal, '99999999999999.99');
    },
  );

  group('documented wallet transport', () {
    late RegistrationAdapter adapter;
    late ApiClient client;
    late WalletRepository repository;
    setUp(() {
      adapter = RegistrationAdapter();
      client = ApiClient(
        config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        adapter: adapter,
        tokenProvider: SessionAccessTokenProvider(
          FakeSessionStorage()..session = walletSession(),
          now: () => testNow,
        ),
      );
      repository = WalletRepository(client);
    });
    tearDown(() => client.close(force: true));

    test(
      'only a missing wallet triggers an authenticated bodyless open',
      () async {
        adapter.handler = (options) => ResponseBody.fromString(
          jsonEncode(
            options.method == 'GET'
                ? {'detail': 'Wallet not found'}
                : walletBalanceJson(),
          ),
          options.method == 'GET' ? 404 : 200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
        final balance = await repository.balance();
        expect(balance.available.decimal, '12480.00');
        expect(adapter.requests.map((r) => r.method), ['GET', 'PUT']);
        expect(
          adapter.requests.every((r) => r.path == '/me/wallets/LKR'),
          isTrue,
        );
        expect(adapter.requests.last.data, isNull);
        expect(
          adapter.requests.last.headers['Authorization'],
          'Bearer synthetic-access',
        );
      },
    );

    test(
      '503 cannot create a wallet and errors retain the backend detail',
      () async {
        adapter.handler = (_) => ResponseBody.fromString(
          '{"detail":"Payments unavailable"}',
          503,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
        await expectLater(
          repository.balance(),
          throwsA(isA<NetworkException>()),
        );
        expect(adapter.requests, hasLength(1));
      },
    );

    test('wallet list, direct capabilities, reconciliation and methods use authenticated reads', () async {
      adapter.responses['/me/wallets'] = [walletBalanceJson()];
      adapter.responses['/me/wallet-capabilities'] = {
        'walletLedger': true,
        'topups': true,
        'cardLinking': true,
        'bankLinking': true,
        'withdrawals': true,
      };
      adapter.responses['/me/wallets/LKR/reconciliation'] = {
        'walletId': 10,
        'balanced': true,
        'available': '12480.0000',
        'reserved': '0E-8',
        'pending': '2350',
      };
      adapter.responses['/me/payment-methods'] = [];
      expect((await repository.wallets()).single.id, 10);
      expect((await repository.walletCapabilities()).bankLinking, isTrue);
      final report = await repository.reconciliation();
      expect(report.available.decimal, '12480.00');
      expect(report.reserved.decimal, '0.00');
      expect(await repository.methods(), isEmpty);
      expect(
        adapter.requests.every(
          (request) =>
              request.method == 'GET' &&
              request.data == null &&
              request.headers['Authorization'] == 'Bearer synthetic-access',
        ),
        isTrue,
      );
    });

    test('withdrawal, intent reads and every documented mock outcome use exact transport', () async {
      final intent = {
        'intentId': 22,
        'purpose': 'WITHDRAWAL',
        'amount': 100,
        'status': 'PENDING',
      };
      adapter.responses['/me/wallets/LKR/withdrawals'] = intent;
      adapter.responses['/me/payment-intents/22'] = intent;
      adapter.responses['/me/mock-payments/22/events'] = intent;
      await repository.create(
        WalletRequest(
          purpose: 'WITHDRAWAL',
          amount: WalletMoney.parse('100'),
          methodId: 6,
          key: 'withdrawal-test',
        ),
      );
      expect(adapter.requests.last.data, '{"amount":100.00,"methodId":6}');
      expect(
        adapter.requests.last.headers['Idempotency-Key'],
        'withdrawal-test',
      );
      await repository.intent(22);
      expect(adapter.requests.last.method, 'GET');
      for (final outcome in ['SUCCESS', 'FAILURE', 'PENDING', 'REFUND']) {
        await repository.simulate(22, outcome);
        expect(adapter.requests.last.method, 'POST');
        expect(adapter.requests.last.data, {'outcome': outcome});
        expect(
          adapter.requests.last.headers['Authorization'],
          'Bearer synthetic-access',
        );
      }
    });

    test('top-up sends exact decimal JSON and the caller retry key, without owner or success flags', () async {
      adapter.responses['/me/wallets/LKR/topups'] = {
        'intentId': 21,
        'purpose': 'TOPUP',
        'amount': 1000,
        'status': 'PENDING',
      };
      final request = WalletRequest(
        purpose: 'TOPUP',
        amount: WalletMoney.parse('99999999999999.99'),
        methodId: 5,
        key: 'same-logical-request',
      );
      await repository.create(request);
      await repository.create(request);
      expect(adapter.requests.map((r) => r.headers['Idempotency-Key']), [
        'same-logical-request',
        'same-logical-request',
      ]);
      expect(
        adapter.requests.first.data,
        '{"amount":99999999999999.99,"methodId":5}',
      );
      expect(
        adapter.requests.every((r) => r.path == '/me/wallets/LKR/topups'),
        isTrue,
      );
    });

    test(
      'method setup sends only a type query and history requests Spring paging',
      () async {
        adapter.responses['/me/payment-methods/setup'] = {
          'methodId': 77,
          'type': 'BANK_ACCOUNT',
          'displayLabel': 'TEST BANK',
          'status': 'VERIFIED_MOCK',
        };
        adapter.responses['/me/wallets/LKR/transactions'] = {
          'content': [],
          'number': 2,
          'last': true,
        };
        expect((await repository.setup('BANK_ACCOUNT')).id, 77);
        expect(adapter.requests.last.queryParameters, {'type': 'BANK_ACCOUNT'});
        expect(adapter.requests.last.data, isNull);
        expect((await repository.history(page: 2)).entries, isEmpty);
        expect(adapter.requests.last.queryParameters, {'page': 2, 'size': 20});
      },
    );
  });

  group('safe payment controller', () {
    late ProviderContainer container;
    late FakeWalletRepository repository;
    late MemoryWalletJournal journal;
    setUp(() {
      repository = FakeWalletRepository();
      journal = MemoryWalletJournal();
      container = ProviderContainer(
        overrides: [
          appSessionStateProvider.overrideWith(
            (ref) async => AppSessionState.authenticated,
          ),
          sessionStorageProvider.overrideWithValue(
            FakeSessionStorage()..session = walletSession(),
          ),
          walletRepositoryProvider.overrideWithValue(repository),
          walletJournalProvider.overrideWithValue(journal),
        ],
      );
    });
    tearDown(() => container.dispose());

    test(
      'concurrent submits create one payment and 503 reloads capabilities',
      () async {
        await container.read(walletControllerProvider.future);
        final controller = container.read(walletControllerProvider.notifier);
        repository.snapshot = walletSnapshot(enabled: false);
        repository.createError = const NetworkException(
          kind: NetworkExceptionKind.badResponse,
          message: 'Payments unavailable',
          statusCode: 503,
        );
        await Future.wait([
          controller.submit('TOPUP', WalletMoney.parse('1000'), 5),
          controller.submit('TOPUP', WalletMoney.parse('1000'), 5),
        ]);
        expect(repository.creates, 1);
        expect(
          container
              .read(walletControllerProvider)
              .requireValue
              .snapshot
              .capabilities
              .topups,
          isFalse,
        );
        expect(journal.requests[25], isNotNull);
      },
    );

    test('timeout and process restart retry the identical persisted request; pending is not success', () async {
      await container.read(walletControllerProvider.future);
      final controller = container.read(walletControllerProvider.notifier);
      repository.createError = const NetworkException(
        kind: NetworkExceptionKind.timeout,
        message: 'Request timed out',
      );
      await controller.submit('TOPUP', WalletMoney.parse('1000'), 5);
      final key = journal.requests[25]!.key;
      expect(journal.requests[25]!.intentId, isNull);
      expect(repository.events, 0);
      repository.createError = null;
      container.invalidate(walletControllerProvider);
      await container.read(walletControllerProvider.future);
      await container.read(walletControllerProvider.notifier).checkPayment();
      expect(repository.lastRequest!.key, key);
      expect(journal.requests[25]!.intentId, 21);
      expect(
        container.read(walletControllerProvider).requireValue.intent!.status,
        'PENDING',
      );
      expect(repository.events, 0);
      await container
          .read(walletControllerProvider.notifier)
          .simulate('SUCCESS');
      expect(journal.requests[25], isNull);
      expect(
        container.read(walletControllerProvider).requireValue.intent!.status,
        'SUCCEEDED',
      );
      expect(repository.events, 1);
    });

    test(
      'reconciliation failure and excess withdrawal block payment creation',
      () async {
        repository.snapshot = walletSnapshot(balanced: false);
        await container.read(walletControllerProvider.future);
        await container
            .read(walletControllerProvider.notifier)
            .submit('TOPUP', WalletMoney.parse('10'), 5);
        expect(repository.creates, 0);
        repository.snapshot = walletSnapshot();
        await container.read(walletControllerProvider.notifier).refresh();
        await container
            .read(walletControllerProvider.notifier)
            .submit('WITHDRAWAL', WalletMoney.parse('15000'), 6);
        expect(repository.creates, 0);
        expect(journal.requests, isEmpty);
      },
    );

    test(
      'method linking follows its capability even if the ledger is unbalanced',
      () async {
        repository.snapshot = walletSnapshot(balanced: false);
        await container.read(walletControllerProvider.future);
        await container
            .read(walletControllerProvider.notifier)
            .addMethod('CARD');
        expect(repository.setups, 1);
        expect(
          container
              .read(walletControllerProvider)
              .requireValue
              .snapshot
              .balanced,
          isFalse,
        );
      },
    );

    test(
      'terminal payment IDs survive journal clearing and controller recreation',
      () async {
        await container.read(walletControllerProvider.future);
        final controller = container.read(walletControllerProvider.notifier);
        await controller.submit('TOPUP', WalletMoney.parse('10'), 5);
        await controller.simulate('SUCCESS');
        expect(journal.requests, isEmpty);
        expect(await controller.savedIntentIds(), [21]);
        container.invalidate(walletControllerProvider);
        await container.read(walletControllerProvider.future);
        expect(
          await container
              .read(walletControllerProvider.notifier)
              .savedIntentIds(),
          [21],
        );
      },
    );

    test(
      'refund checks a fresh successful top-up and blocks withdrawal refunds',
      () async {
        await container.read(walletControllerProvider.future);
        final controller = container.read(walletControllerProvider.notifier);
        repository.currentIntent = WalletIntent.fromJson({
          'intentId': 21,
          'purpose': 'WITHDRAWAL',
          'status': 'SUCCEEDED',
          'amount': 1000,
        });
        await controller.refund(21);
        expect(repository.events, 0);
        repository.currentIntent = WalletIntent.fromJson({
          'intentId': 21,
          'purpose': 'TOPUP',
          'status': 'SUCCEEDED',
          'amount': 1000,
        });
        await controller.refund(21);
        expect(repository.events, 1);
        expect(
          container.read(walletControllerProvider).requireValue.intent!.status,
          'REFUNDED',
        );
      },
    );

    test(
      'server-disabled capabilities block actions even when methods exist',
      () async {
        repository.snapshot = walletSnapshot(enabled: false);
        await container.read(walletControllerProvider.future);
        await container
            .read(walletControllerProvider.notifier)
            .submit('TOPUP', WalletMoney.parse('10'), 5);
        expect(repository.creates, 0);
      },
    );
  });

  testWidgets(
    'top-up validates precision and requires an explicit simulated result',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = ServiceFixture()..storage.session = walletSession();
      await pump(tester, fixture, route: AppRoutes.wallet);
      final repository = fixture.container.read(
        walletRepositoryProvider,
      ) as FakeWalletRepository;
      await tester.tap(find.text('Top Up Wallet'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('wallet-payment-amount')),
        '1000.001',
      );
      await tester.tap(find.text('Create top-up'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter an amount with at most two decimals.'),
        findsOneWidget,
      );
      expect(repository.creates, 0);
      await tester.enterText(
        find.byKey(const ValueKey('wallet-payment-amount')),
        '1000',
      );
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST CARD **** 4242').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create top-up'));
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(repository.events, 0);
      expect(find.text('Confirm payment'), findsWidgets);
      await tester.tap(find.text('Confirm payment').last);
      await tester.pumpAndSettle();
      expect(repository.events, 1);
      expect(
        find.text('Payment completed. Your balance has been refreshed.'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'adding both method types calls setup and refreshes visible methods',
    (tester) async {
      final fixture = ServiceFixture()..storage.session = walletSession();
      final repository = fixture.container.read(
        walletRepositoryProvider,
      ) as FakeWalletRepository;
      repository.snapshot = walletSnapshot(empty: true);
      await pump(tester, fixture, route: AppRoutes.wallet);
      await walletScrollTo(tester, 'Add New Payment Method');
      await tester.tap(find.text('Add New Payment Method'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add card'));
      await tester.pumpAndSettle();
      expect(repository.setups, 1);
      expect(repository.snapshot.methods.single.card, isTrue);
      await tester.tap(find.text('Add bank account'));
      await tester.pumpAndSettle();
      expect(repository.setups, 2);
      expect(repository.snapshot.methods.length, 2);
    },
  );

  testWidgets(
    'disabled server setup remains visible with explanation and refresh',
    (tester) async {
      final fixture = ServiceFixture();
      final repository = fixture.container.read(
        walletRepositoryProvider,
      ) as FakeWalletRepository;
      repository.snapshot = walletSnapshot(enabled: false, empty: true);
      await pump(tester, fixture, route: AppRoutes.wallet);
      await walletScrollTo(tester, 'Add New Payment Method');
      await tester.tap(find.text('Add New Payment Method'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The server has disabled'), findsOneWidget);
      expect(find.text('Add card'), findsNothing);
      repository.snapshot = walletSnapshot(empty: true);
      await tester.tap(find.text('Refresh availability'));
      await tester.pumpAndSettle();
      expect(find.text('Add card'), findsOneWidget);
      expect(repository.setups, 0);
    },
  );

  testWidgets('saved status and refund require explicit confirmation', (
    tester,
  ) async {
    final fixture = ServiceFixture()..storage.session = walletSession();
    final repository = fixture.container.read(
      walletRepositoryProvider,
    ) as FakeWalletRepository;
    repository.currentIntent = WalletIntent.fromJson({
      'intentId': 21,
      'purpose': 'TOPUP',
      'status': 'SUCCEEDED',
      'amount': 1000,
    });
    await pump(tester, fixture, route: AppRoutes.wallet);
    await walletScrollTo(tester, 'Payment status');
    await tester.tap(find.text('Payment status'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Payment ID'), '21');
    await tester.tap(find.text('Check status'));
    await tester.pumpAndSettle();
    expect(find.text('Status: SUCCEEDED'), findsOneWidget);
    await tester.ensureVisible(find.text('Refund top-up'));
    await tester.tap(find.text('Refund top-up'));
    await tester.pumpAndSettle();
    expect(repository.events, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.events, 0);
    await tester.ensureVisible(find.text('Refund top-up'));
    await tester.tap(find.text('Refund top-up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm refund'));
    await tester.pumpAndSettle();
    expect(repository.events, 1);
    expect(find.text('Status: REFUNDED'), findsOneWidget);
  });

  testWidgets('wallet details displays server wallets and ledger totals', (
    tester,
  ) async {
    await pump(tester, ServiceFixture(), route: AppRoutes.wallet);
    await walletScrollTo(tester, 'Wallet details');
    await tester.tap(find.text('Wallet details'));
    await tester.pumpAndSettle();
    expect(find.text('LKR wallet #10'), findsOneWidget);
    expect(find.text('Balance verified against the ledger'), findsOneWidget);
    expect(
      find.textContaining('Ledger available: LKR 12,480.00'),
      findsOneWidget,
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'wallet renders live sections and grouped operations at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final fixture = ServiceFixture();
        await pump(tester, fixture, route: AppRoutes.wallet);
        expect(find.byType(WalletScreen), findsOneWidget);
        expect(find.text('Available Balance'), findsOneWidget);
        expect(find.textContaining('12,480.00'), findsNWidgets(2));
        await tester.scrollUntilVisible(
          find.text('Recent Transactions'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(WalletScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Wallet transfer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

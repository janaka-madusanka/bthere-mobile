import 'package:customer_app/features/wallet/data/customer_wallet_repository.dart';
import 'package:customer_app/features/booking/presentation/booking_saved_cards_dialog.dart';

import 'dart:async';

import 'package:customer_app/features/wallet/application/customer_wallet_controller.dart';
import 'package:customer_app/features/wallet/presentation/customer_wallet_screen.dart';
import 'package:customer_app/features/discovery/presentation/customer_bottom_navigation.dart';
import 'package:customer_app/app/widgets/customer_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_discovery_test.dart'
    show marketEntry, continueMarket, waitForState;
import 'wallet_fixture.dart';

Future<void> openWallet(WidgetTester tester, WalletFixture f) async {
  await marketEntry(tester, f.f);
  await continueMarket(tester);
  await tester.tap(find.byKey(const ValueKey('customer-nav-wallet')));
  await tester.pumpAndSettle();
}

CustomerWalletController walletController(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CustomerWalletScreen)))
        .read(customerWalletProvider);

void main() {
  testWidgets(
    'booking card chooser uses the selected real method ID without inventing expiry or default metadata',
    (tester) async {
      final f = WalletFixture();
      f.methods = [
        {
          'methodId': 5,
          'type': 'CARD',
          'displayLabel': 'Test Visa 4242',
          'status': 'VERIFIED_MOCK',
          'brand': 'VISA',
        },
        {
          'methodId': 7,
          'type': 'CARD',
          'displayLabel': 'Test Mastercard 4444',
          'status': 'VERIFIED_MOCK',
          'brand': 'MASTERCARD',
        },
      ];
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      final context = tester.element(find.byType(CustomerWalletScreen));
      final result = showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => BookingSavedCardsDialog(
          repository: walletController(tester).repository,
          onAddCard: () async {},
        ),
      );
      await tester.pumpAndSettle();
      final use = find.byKey(const ValueKey('booking-use-selected-card'));
      expect(tester.widget<FilledButton>(use).onPressed, isNull);
      expect(find.text('Default'), findsNothing);
      expect(find.textContaining('Expires'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('booking-saved-card-7')));
      await tester.pumpAndSettle();
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect((await result)!['methodId'], 7);
      expect(
        f.f.adapter.requests.where(
          (r) => r.method == 'POST' && r.path.startsWith('/me/'),
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'Manage shows compact saved cards and opens the existing add card dialog',
    (tester) async {
      final f = WalletFixture();
      f.capabilities['cardLinking'] = true;
      f.methods = [
        {
          'methodId': 5,
          'type': 'CARD',
          'displayLabel': 'TEST CARD 4242',
          'status': 'VERIFIED_MOCK',
        },
      ];
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      await tester.ensureVisible(find.text('Manage'));
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      expect(find.text('Your saved cards'), findsOneWidget);
      expect(
        find.byTooltip('Payment method details').hitTestable(),
        findsNothing,
      );
      await tester.tap(find.text('Add new payment method').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Add New Card'), findsOneWidget);
      expect(find.text('Add test bank account'), findsNothing);
    },
  );

  testWidgets(
    'View all opens full history with pagination and returns to the wallet',
    (tester) async {
      final f = WalletFixture()..last = false;
      f.entries = [
        for (var i = 1; i <= 4; i++)
          {
            'entryId': i,
            'operationId': i,
            'currencyCode': 'LKR',
            'bucket': 'AVAILABLE',
            'delta': i,
            'createdAt': '2026-10-28T10:00:00Z',
            'type': 'TOPUP',
          },
      ];
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      expect(find.text('Wallet top-up'), findsNWidgets(3));
      final controller = walletController(tester);
      await tester.ensureVisible(find.text('View all'));
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wallet-full-history')), findsOneWidget);
      expect(find.text('Wallet top-up'), findsNWidgets(4));
      f.entries = [
        ...f.entries,
        {
          'entryId': 5,
          'operationId': 5,
          'currencyCode': 'LKR',
          'bucket': 'AVAILABLE',
          'delta': 5,
          'createdAt': '2026-10-28T11:00:00Z',
          'type': 'TOPUP',
        },
      ];
      f.last = true;
      final more = find.byKey(const ValueKey('wallet-history-load-more'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(controller.entries, hasLength(5));
      expect(more, findsNothing);
      await tester.tap(find.byTooltip('Back to wallet'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wallet-full-history')), findsNothing);
      expect(find.text('Manage'), findsOneWidget);
    },
  );
  testWidgets(
    'Add Money validates custom amounts and remains usable with a narrow keyboard viewport',
    (tester) async {
      final f = WalletFixture();
      f.capabilities['topups'] = true;
      addTearDown(f.f.dispose);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openWallet(tester, f);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-wallet-add-money')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-wallet-add-money')));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('topup-amount'));
      await tester.ensureVisible(input);
      await tester.enterText(input, '0');
      final submit = find.byKey(const ValueKey('topup-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
      await tester.ensureVisible(input);
      await tester.enterText(input, '12.345');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text('Enter an amount with up to two decimal places.'),
        findsOneWidget,
      );
      expect(f.topupIntent, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Add Money requires a card, creates a pending topup and confirms test funds separately',
    (tester) async {
      final f = WalletFixture();
      f.capabilities['topups'] = true;
      f.methods = [
        {
          'methodId': 5,
          'type': 'CARD',
          'displayLabel': 'TEST CARD 4242',
          'status': 'VERIFIED_MOCK',
        },
      ];
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      await tester.tap(find.byKey(const ValueKey('customer-wallet-add-money')));
      await tester.pumpAndSettle();
      expect(find.text('Quick Amounts'), findsOneWidget);
      final submit = find.byKey(const ValueKey('topup-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Choose a saved card to continue.'), findsOneWidget);
      expect(f.topupIntent, isNull);
      await tester.ensureVisible(find.byType(RadioListTile<int>));
      await tester.tap(find.byType(RadioListTile<int>));
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(f.topupIntent!['status'], 'PENDING');
      expect(f.balance['available'], 0);
      expect(find.text('Complete test payment'), findsOneWidget);
      final request = f.f.adapter.requests.singleWhere(
        (r) => r.path == '/me/wallets/LKR/topups',
      );
      expect(request.headers['Idempotency-Key'], isNotEmpty);
      expect((request.data as Map)['methodId'], 5);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(f.topupIntent!['status'], 'SUCCEEDED');
      expect(walletController(tester).data!.balance!['available'], '1000');
      expect(
        find.text('Test top-up completed. Wallet refreshed.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'topup timeout retry retains the original idempotency key and amount',
    (tester) async {
      final f = WalletFixture();
      f.capabilities['topups'] = true;
      f.topupStatus = 503;
      f.methods = [
        {
          'methodId': 5,
          'type': 'CARD',
          'displayLabel': 'TEST CARD 4242',
          'status': 'VERIFIED_MOCK',
        },
      ];
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      await tester.tap(find.byKey(const ValueKey('customer-wallet-add-money')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(RadioListTile<int>));
      await tester.tap(find.byType(RadioListTile<int>));
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('topup-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Retry same top-up'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      f.topupStatus = 201;
      await tester.tap(find.byKey(const ValueKey('customer-wallet-add-money')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final requests = f.f.adapter.requests
          .where((r) => r.path == '/me/wallets/LKR/topups')
          .toList();
      expect(requests, hasLength(2));
      expect(
        requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key'],
      );
      expect(requests[0].data, requests[1].data);
      expect(f.balance['available'], 0);
    },
  );
  testWidgets(
    'payment method opens card dialog directly and never exposes bank linking',
    (tester) async {
      final f = WalletFixture();
      f.methods = [
        {
          'methodId': 6,
          'type': 'BANK_ACCOUNT',
          'displayLabel': 'TEST BANK',
          'status': 'VERIFIED_MOCK',
        },
      ];
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      expect(find.text('TEST BANK'), findsNothing);
      await tester.ensureVisible(find.text('Add new payment method'));
      await tester.tap(find.text('Add new payment method'));
      await tester.pumpAndSettle();
      expect(find.text('Add New Card'), findsOneWidget);
      expect(find.text('Add test bank account'), findsNothing);
      expect(
        find.text('Card setup is not enabled yet. Please try again later.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('submit-test-card')),
            )
            .onPressed,
        isNull,
      );
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/setup')),
        isEmpty,
      );
    },
  );
  testWidgets(
    'initial empty wallet fits a phone viewport and can still scroll when needed',
    (tester) async {
      await tester.runAsync(() async {
        await (FontLoader(
              'Public Sans',
            )..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf')))
            .load();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final f = WalletFixture();
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      final content = find.byKey(const ValueKey('customer-wallet-scroll'));
      final scrollable = find
          .descendant(of: content, matching: find.byType(Scrollable))
          .first;
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'logout clears wallet and discards a delayed balance response',
    () async {
      final f = WalletFixture();
      addTearDown(f.f.dispose);
      await f.f.controller.login('test', 'password');
      final c = CustomerWalletController(
        CustomerWalletRepository(f.f.service),
        f.f.controller,
      );
      addTearDown(c.dispose);
      await waitForState(c, () => !c.loading);
      expect(c.data, isNotNull);
      f.pendingWallet = Completer<void>();
      f.walletReadStarted = Completer<void>();
      final pending = c.load();
      await f.walletReadStarted!.future;
      await f.f.controller.logout();
      expect(c.data, isNull);
      f.pendingWallet!.complete();
      await pending;
      expect(c.data, isNull);
      expect(c.entries, isEmpty);
    },
  );

  testWidgets(
    'history groups bucket movements and adds pages without duplicate entries',
    (tester) async {
      Map<String, dynamic> row(
        int id,
        int operation,
        String bucket,
        int delta,
      ) => {
        'entryId': id,
        'operationId': operation,
        'currencyCode': 'LKR',
        'bucket': bucket,
        'delta': delta,
        'createdAt': '2026-10-26T10:00:00',
        'type': 'BOOKING_RESERVE',
      };
      final f = WalletFixture()..last = false;
      addTearDown(f.f.dispose);
      f.entries = [
        row(31, 41, 'AVAILABLE', -500),
        row(32, 41, 'RESERVED', 500),
      ];
      await openWallet(tester, f);
      expect(find.text('Booking reservation'), findsOneWidget);
      expect(find.text('-Rs. 500.00'), findsOneWidget);
      f.entries = [
        row(32, 41, 'RESERVED', 500),
        row(33, 42, 'AVAILABLE', -100),
      ];
      f.last = true;
      await tester.runAsync(() => walletController(tester).more());
      await tester.pumpAndSettle();
      expect(walletController(tester).entries, hasLength(3));
      expect(find.text('Booking reservation'), findsNWidgets(2));
    },
  );
  test('wallet formatting uses exact decimal minor units', () {
    expect(walletMoney('99999999999999.99'), 'Rs. 99,999,999,999,999.99');
    expect(walletMoney('-0.01'), '-Rs. 0.01');
    expect(walletMoney(1e3), 'Rs. 1,000.00');
    expect(() => walletMinorUnits('1.001'), throwsFormatException);
  });
  testWidgets(
    'initial wallet uses shared chrome and real empty responses without money writes',
    (tester) async {
      final f = WalletFixture();
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      expect(find.byType(CustomerTopBar), findsOneWidget);
      expect(
        tester
            .widget<CustomerBottomNavigation>(
              find.byType(CustomerBottomNavigation),
            )
            .selected,
        CustomerNavigationTab.wallet,
      );
      expect(find.text('No payment methods yet'), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Rs. 0.00'), findsNWidgets(3));
      expect(
        f.f.adapter.requests.where(
          (r) => r.method != 'GET' && r.path.startsWith('/me/'),
        ),
        isEmpty,
      );
      await tester.tap(
        find.byKey(const ValueKey('customer-wallet-visibility')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rs. 0.00'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('customer-nav-home')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerWalletScreen), findsNothing);
    },
  );
  testWidgets(
    'wallet errors do not masquerade as zero balance and retry recovers',
    (tester) async {
      final f = WalletFixture()..walletStatus = 503;
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      expect(find.text('Rs. 0.00'), findsNothing);
      expect(find.text('No transactions yet'), findsNothing);
      f.walletStatus = 200;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No transactions yet'), findsOneWidget);
    },
  );
  testWidgets(
    'missing wallet opens explicitly and imbalance blocks money actions',
    (tester) async {
      final f = WalletFixture()..walletStatus = 404;
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      expect(find.text('Open wallet'), findsOneWidget);
      expect(f.f.adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
      await tester.tap(find.text('Open wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Add money'), findsOneWidget);
      f.balanced = false;
      await tester.runAsync(() => walletController(tester).load());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('customer-wallet-add-money')),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'mock methods require explicit selection and refresh their server labels',
    (tester) async {
      final f = WalletFixture();
      f.capabilities['cardLinking'] = true;
      addTearDown(f.f.dispose);
      await openWallet(tester, f);
      await tester.ensureVisible(find.text('Add new payment method'));
      await tester.tap(find.text('Add new payment method'));
      await tester.pumpAndSettle();
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/setup')),
        isEmpty,
      );
      expect(find.text('Add New Card'), findsOneWidget);
      expect(find.text('Add test bank account'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('cardholder-name')),
        'Test Customer',
      );
      await tester.enterText(
        find.byKey(const ValueKey('card-number')),
        '4242424242424242',
      );
      await tester.enterText(find.byKey(const ValueKey('card-expiry')), '1235');
      await tester.enterText(find.byKey(const ValueKey('card-cvv')), '123');
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-test-card')),
      );
      await tester.tap(find.byKey(const ValueKey('submit-test-card')));
      await tester.pumpAndSettle();
      expect(find.text('TEST CARD •••• 4242'), findsOneWidget);
      final setup = f.f.adapter.requests.singleWhere(
        (r) => r.path.contains('/setup'),
      );
      expect(setup.data, isNull);
      expect(find.text('Test payment method'), findsOneWidget);
    },
  );
  testWidgets('narrow large text keeps wallet actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final f = WalletFixture();
    addTearDown(f.f.dispose);
    await marketEntry(tester, f.f);
    await continueMarket(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-nav-wallet')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-nav-wallet')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('No transactions yet'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

import 'package:customer_app/features/booking/application/customer_request_recovery.dart';
import 'package:customer_app/features/booking/data/customer_active_request_notifications.dart';
import 'package:customer_app/features/booking/data/customer_request_recovery_store.dart';
import 'package:customer_app/features/discovery/presentation/customer_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_request_payment_widget_test.dart' show ready;
import 'customer_auth_test.dart' show clock;

void main() {
  final channel = AndroidActiveRequestNotifications.channel;
  final calls = <MethodCall>[];
  Map<String, dynamic>? initialOpen;
  setUp(() {
    calls.clear();
    initialOpen = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialOpen') return initialOpen;
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets(
    'matching request survives restart, then accepts and pays the same request',
    (tester) async {
      final f = await ready(tester, status: 'MATCHING');
      expect(
        find.byKey(const ValueKey('active-matching-request-501')),
        findsOneWidget,
      );
      expect(
        calls.where((c) => c.method == 'show').last.arguments,
        containsPair('title', 'Finding a provider'),
      );
      f.requestEvents = [];
      await tester.pumpWidget(const SizedBox());
      await f.f.pump(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('active-matching-request-501')),
        findsOneWidget,
      );
      expect(find.byType(CustomerHomeScreen), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('active-matching-request-501')),
      );
      await tester.tap(
        find.byKey(const ValueKey('active-matching-request-501')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byKey(const ValueKey('booking-finding-provider')),
        findsOneWidget,
      );
      expect(find.text('Confirm and Pay'), findsNothing);
      expect(
        f.f.adapter.requests.where(
          (r) => r.method == 'POST' && r.path.contains('/booking-requests/'),
        ),
        isEmpty,
      );
      f.requestViewBody.addAll({
        'status': 'AWAITING_CUSTOMER_CONFIRMATION',
        'providerId': 15,
        'confirmationExpiresAt': clock
            .add(const Duration(minutes: 2))
            .toIso8601String(),
      });
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Confirm and Pay'), findsOneWidget);
      final pay = find.text('Confirm and Pay');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(find.text('Your booking is confirmed!'), findsOneWidget);
      expect(
        f.f.adapter.requests
            .where(
              (r) =>
                  r.method == 'POST' && r.path.endsWith('/501/confirm-wallet'),
            )
            .length,
        1,
      );
      expect(
        f.f.adapter.requests.where(
          (r) => r.method == 'POST' && r.path.endsWith('/booking-requests'),
        ),
        isEmpty,
      );
      expect(calls.where((c) => c.method == 'clear'), isNotEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'matching references are account scoped and terminal requests leave recovery',
    (tester) async {
      final f = await ready(tester, status: 'MATCHING');
      final recovery = ProviderScope.containerOf(
        tester.element(find.byType(CustomerHomeScreen)),
      ).read(customerRequestRecoveryProvider);
      expect(recovery.active.single['status'], 'MATCHING');
      expect(
        await CustomerRequestRecoveryStore(recovery.selection, 99).read(),
        isEmpty,
      );
      f.requestViewBody['status'] = 'UNMATCHED';
      final update = recovery.refresh();
      await tester.pumpAndSettle();
      await update;
      expect(
        find.byKey(const ValueKey('active-matching-request-501')),
        findsNothing,
      );
      expect(recovery.active, isEmpty);
      expect(calls.last.method, 'clear');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cold notification opens only after correct owner and environment restore',
    (tester) async {
      initialOpen = {
        'owner': 12,
        'scope': 'https://example.invalid/api/v1',
        'requestId': 501,
      };
      final f = await ready(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Confirm and Pay'), findsOneWidget);
      expect(
        f.f.adapter.requests.where(
          (r) => r.method == 'POST' && r.path.contains('/booking-requests/'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('wrong-account notification cannot open its request', (
    tester,
  ) async {
    initialOpen = {
      'owner': 99,
      'scope': 'https://example.invalid/api/v1',
      'requestId': 999,
    };
    final f = await ready(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(
      f.f.adapter.requests.where(
        (r) => r.path.contains('/booking-requests/999'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'background stops status polling; resume refreshes acceptance and notification',
    (tester) async {
      final f = await ready(tester, status: 'MATCHING');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final reads = f.f.adapter.requests.length;
      await tester.pump(const Duration(seconds: 15));
      expect(f.f.adapter.requests.length, reads);
      expect(
        calls.where((c) => c.method == 'show').last.arguments,
        containsPair('title', 'Your booking request is active'),
      );
      f.requestViewBody.addAll({
        'status': 'AWAITING_CUSTOMER_CONFIRMATION',
        'confirmationExpiresAt': clock
            .add(const Duration(minutes: 2))
            .toIso8601String(),
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Payment required'), findsOneWidget);
      expect(
        calls.where((c) => c.method == 'show').last.arguments,
        containsPair('title', 'Provider found - confirm payment'),
      );
      expect(
        f.f.adapter.requests.where(
          (r) => r.method == 'POST' && r.path.contains('/booking-requests/'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('wrong-environment notification never opens the saved request', (
    tester,
  ) async {
    initialOpen = {
      'owner': 12,
      'scope': 'https://other.invalid/api/v1',
      'requestId': 999,
    };
    final f = await ready(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(
      f.f.adapter.requests.where(
        (r) => r.path.contains('/booking-requests/999'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'denied or unavailable OS notification cannot block request recovery',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'show') {
              throw PlatformException(code: 'permission-denied');
            }
            return null;
          });
      await ready(tester, status: 'MATCHING');
      expect(
        find.byKey(const ValueKey('active-matching-request-501')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

import 'dart:async';

import 'package:bthere_network/bthere_network.dart';

import 'package:customer_app/features/auth/application/customer_auth_controller.dart';
import 'package:customer_app/features/auth/data/customer_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart' show Fixture, clock, openCustomerAccount;

class _PhoneFailureService extends CustomerAuthService {
  _PhoneFailureService(Fixture fixture, this.kind)
    : super(fixture.client, fixture.storage, now: () => clock);
  final NetworkExceptionKind kind;
  @override
  Future<int> requestPhoneOtp(String phoneNumber) async =>
      throw NetworkException(kind: kind, message: 'Transport failure');
}

void main() {
  for (final entry in {
    NetworkExceptionKind.connection:
        'Unable to reach the sign-in service. Please try again shortly.',
    NetworkExceptionKind.timeout: 'The request timed out. Please try again.',
  }.entries) {
    test(
      'phone ${entry.key.name} does not claim an unknown account or OTP success',
      () async {
        final f = Fixture();
        addTearDown(f.dispose);
        final controller = CustomerAuthController(
          _PhoneFailureService(f, entry.key),
        );
        addTearDown(controller.dispose);
        await controller.requestPhoneOtp('+94771234567');
        expect(controller.error, entry.value);
        expect(controller.verificationPhone, isNull);
        expect(f.storage.value, isNull);
        expect(f.adapter.requests, isEmpty);
      },
    );
  }
  test(
    'phone request and verification use exact public Customer payloads',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.phoneOnly = true;
      await f.service.requestPhoneOtp(' +94771234567 ');
      expect(f.storage.value, isNull);
      var request = f.adapter.requests.last;
      expect(request.path, '/auth/otp/request');
      expect(request.method, 'POST');
      expect(request.data, {
        'phoneNumber': '+94771234567',
        'accountType': 'CUSTOMER',
      });
      expect(request.headers['Authorization'], isNull);
      final session = await f.service.verifyPhoneOtp('+94771234567', '001234');
      request = f.adapter.requests.last;
      expect(request.path, '/auth/otp/verify');
      expect(request.data, {
        'phoneNumber': '+94771234567',
        'otp': '001234',
        'accountType': 'CUSTOMER',
      });
      expect(request.headers['Authorization'], isNull);
      expect(session.user?.email, isNull);
      expect(f.storage.value?.accessToken, 'access-one');
      expect(f.storage.value?.refreshToken, 'refresh-one');
      expect(
        f.storage.value?.expiresAt,
        clock.add(const Duration(seconds: 123)),
      );
    },
  );

  test('invalid phone and OTP are rejected before HTTP', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    for (final phone in [
      '0771234567',
      '+012345678',
      '+9477 1234567',
      '+123',
      '+1234567890123456',
    ]) {
      await expectLater(
        f.service.requestPhoneOtp(phone),
        throwsA(isA<CustomerAuthFailure>()),
      );
    }
    await expectLater(
      f.service.verifyPhoneOtp('+94771234567', '12345'),
      throwsA(isA<CustomerAuthFailure>()),
    );
    expect(f.adapter.requests, isEmpty);
  });

  for (final status in [400, 429, 500]) {
    test(
      'phone request $status stays signed out and does not claim OTP success',
      () async {
        final f = Fixture();
        addTearDown(f.dispose);
        f.adapter.phoneRequestStatus = status;
        await f.controller.restore();
        await f.controller.requestPhoneOtp('+94771234567');
        expect(f.controller.stage, CustomerAuthStage.signedOut);
        expect(f.controller.verificationPhone, isNull);
        expect(f.controller.error, isNotNull);
        expect(f.storage.value, isNull);
        if (status == 429) {
          expect(
            f.controller.resendAt,
            clock.add(const Duration(seconds: 120)),
          );
        }
      },
    );
  }

  test(
    'phone verification rejects wrong role, invalid OTP and failed storage',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.role = 'SERVICE_PROVIDER';
      await expectLater(
        f.service.verifyPhoneOtp('+94771234567', '123456'),
        throwsA(isA<CustomerAuthFailure>()),
      );
      expect(f.storage.value, isNull);
      f.adapter.role = 'CUSTOMER';
      f.adapter.phoneVerifyStatus = 401;
      await expectLater(
        f.service.verifyPhoneOtp('+94771234567', '123456'),
        throwsA(isA<CustomerAuthFailure>()),
      );
      expect(f.storage.value, isNull);
      f.adapter.phoneVerifyStatus = 200;
      f.storage.failWrite = true;
      await f.controller.requestPhoneOtp('+94771234567');
      await f.controller.verifyPhoneOtp('123456');
      expect(f.controller.stage, isNot(CustomerAuthStage.authenticated));
      expect(f.controller.verificationPhone, '+94771234567');
    },
  );

  test('duplicate request is blocked and resend honors cooldown', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    var now = clock;
    final controller = CustomerAuthController(
      CustomerAuthService(f.client, f.storage, now: () => now),
    );
    addTearDown(controller.dispose);
    f.adapter.pendingPhone = Completer<void>();
    final pending = controller.requestPhoneOtp('+94771234567');
    await Future<void>.delayed(Duration.zero);
    await controller.requestPhoneOtp('+94771234567');
    f.adapter.pendingPhone!.complete();
    await pending;
    await controller.resend();
    expect(f.adapter.requests.length, 1);
    now = now.add(const Duration(seconds: 61));
    await controller.resend();
    expect(f.adapter.requests.length, 2);
    expect(f.adapter.requests.last.path, '/auth/otp/request');
    controller.cancelVerification();
    expect(controller.verificationPhone, isNull);
  });

  testWidgets(
    'phone-only registration verifies OTP and opens missing-profile form',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.phoneOnly = true;
      f.adapter.profileStatus = 404;
      await f.pump(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-phone-mode')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-phone-mode')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customer-password')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('customer-phone')),
        '+94771234567',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Verify your phone'), findsOneWidget);
      expect(f.storage.value, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('customer-otp')),
        '001234',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Phone verified!'), findsOneWidget);
      expect(f.storage.value, isNotNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-verification-success-continue')),
      );
      await tester.tap(
        find.byKey(const ValueKey('customer-verification-success-continue')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Let’s get to know you'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('customer-profile-firstName')),
        findsOneWidget,
      );
      expect(f.storage.value?.user?.email, isNull);
      expect(
        f.adapter.requests.where((r) => r.path == '/auth/register'),
        isEmpty,
      );
    },
  );
  testWidgets(
    'existing phone account opens account and wrong OTP keeps verification',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.phoneOnly = true;
      await f.pump(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-phone-mode')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-phone-mode')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('customer-phone')),
        '+94771234567',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      f.adapter.phoneVerifyStatus = 401;
      await tester.enterText(
        find.byKey(const ValueKey('customer-otp')),
        '001234',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Verify your phone'), findsOneWidget);
      expect(f.storage.value, isNull);
      f.adapter.phoneVerifyStatus = 200;
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Phone verified!'), findsOneWidget);
      expect(f.storage.value, isNotNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-verification-success-continue')),
      );
      await tester.tap(
        find.byKey(const ValueKey('customer-verification-success-continue')),
      );
      await tester.pumpAndSettle();
      await openCustomerAccount(tester);
      expect(find.text('Welcome, customer12'), findsOneWidget);
      expect(find.text('Your Customer profile is ready.'), findsOneWidget);
    },
  );

  testWidgets('phone OTP back allows returning to unchanged email sign-in', (
    tester,
  ) async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.pump(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-phone-mode')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-phone-mode')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('customer-phone')),
      '+94771234567',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-auth-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use a different phone number'));
    await tester.tap(find.text('Use a different phone number'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('customer-otp')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-phone-mode')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-phone-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('customer-identifier')), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-password')), findsOneWidget);
    expect(f.storage.value, isNull);
    expect(
      f.adapter.requests.where((r) => r.path == '/auth/otp/verify'),
      isEmpty,
    );
  });
}

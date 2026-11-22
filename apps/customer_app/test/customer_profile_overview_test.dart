import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/features/auth/application/customer_auth_controller.dart';
import 'package:customer_app/features/profile/data/customer_profile_overview_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_request_payment_widget_test.dart' show ready;
import 'profile_overview_fixture.dart';

class OverviewBackend {
  Map<String, dynamic> data = profileOverviewJson();
  int otpWrites = 0, verifyWrites = 0, status = 200;
  bool wrongOtp = true;
  void install(BookingFixture f) {
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      final path = Uri.parse(r.path).path;
      Object? body;
      var code = 200;
      if (path == '/customers/me/profile-overview') {
        body = data;
        code = status;
      } else if (path.endsWith('/contacts/email/otp')) {
        otpWrites++;
        body = {
          'destination': (r.data as Map)['email'],
          'expiresIn': 300,
          'resendAfterSeconds': 60,
        };
      } else if (path.endsWith('/contacts/email/verify')) {
        verifyWrites++;
        code = wrongOtp ? 400 : 200;
        body = wrongOtp
            ? {'detail': 'Verification code is invalid or expired'}
            : {
                ...data['contacts'] as Map,
                'email': (r.data as Map)['email'],
                'emailVerified': true,
              };
      } else if (path == '/customers/me/booking-requests') {
        final page = int.parse(r.uri.queryParameters['page']!);
        body = {
          'page': page,
          'size': 20,
          'totalCount': 3,
          'hasMore': page == 0,
          'items': [
            if (page == 0)
              {
                'requestId': 103,
                'jobId': null,
                'status': 'COMPLETED',
                'serviceName': 'Closed service',
              },
            {
              'requestId': 105,
              'jobId': null,
              'status': 'NEW_ACTIVE_STATUS',
              'serviceName': 'Future service',
            },
            if (page == 1)
              {
                'requestId': 106,
                'jobId': null,
                'status': 'MATCHING',
                'serviceName': 'Next page service',
              },
          ],
        };
      } else {
        return previous(r);
      }
      return ResponseBody.fromString(
        jsonEncode(body),
        code,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    };
  }
}

Future<BookingFixture> overview(
  WidgetTester tester,
  OverviewBackend backend,
) async {
  final f = await ready(tester);
  backend.install(f);
  ProviderScope.containerOf(tester.element(find.byType(CustomerApp)))
      .read(customerRouterProvider)
      .go('/account');
  await tester.pumpAndSettle();
  return f;
}

Future<void> press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'overview shows backend identity, separate real/test spending and verification without writes',
    (tester) async {
      final backend = OverviewBackend();
      final f = await overview(tester, backend);
      expect(find.text('Madu Perera'), findsOneWidget);
      expect(find.text('Not verified'), findsOneWidget);
      expect(find.text('LKR 79,000.00'), findsOneWidget);
      expect(find.text('LKR 84,000.00'), findsNothing);
      expect(find.text('Photo is blurry'), findsOneWidget);
      expect(
        f.f.adapter.requests.where(
          (r) => r.method == 'POST' && r.path.contains('/contacts/'),
        ),
        isEmpty,
      );
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'wrong contact OTP stays signed in and cannot resend before server delay',
    (tester) async {
      final backend = OverviewBackend();
      await overview(tester, backend);
      await press(tester, find.text('Manage contact details'));
      await tester.enterText(
        find.byKey(const ValueKey('profile-contact-destination')),
        'new@example.com',
      );
      await press(tester, find.byKey(const ValueKey('profile-contact-submit')));
      expect(backend.otpWrites, 1);
      await tester.enterText(
        find.byKey(const ValueKey('profile-contact-otp')),
        '012345',
      );
      await press(tester, find.byKey(const ValueKey('profile-contact-submit')));
      expect(backend.verifyWrites, 1);
      expect(
        find.text('Verification code is invalid or expired'),
        findsOneWidget,
      );
      expect(
        ProviderScope.containerOf(tester.element(find.byType(CustomerApp)))
            .read(customerAuthControllerProvider)
            .user,
        isNotNull,
      );
      backend.wrongOtp = false;
      await press(tester, find.byKey(const ValueKey('profile-contact-submit')));
      expect(backend.verifyWrites, 2);
      expect(find.text('Manage contact details'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'overview errors retry safely and no saved profile offers completion',
    (tester) async {
      final backend = OverviewBackend()..status = 503;
      final f = await overview(tester, backend);
      expect(find.text('Retry profile'), findsOneWidget);
      backend.status = 200;
      backend.data['profile'] = null;
      await press(tester, find.text('Retry profile'));
      expect(find.text('Complete profile'), findsOneWidget);
      expect(
        f.f.adapter.requests.where(
          (r) => r.method != 'GET' && r.path.contains('profile-overview'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'request list pages, deduplicates and retains unknown active states',
    (tester) async {
      final backend = OverviewBackend();
      (backend.data['pendingServices'] as Map)['hasMore'] = true;
      await overview(tester, backend);
      await press(tester, find.text('View all').first);
      expect(find.text('Future service'), findsOneWidget);
      expect(find.text('Closed service'), findsNothing);
      await press(tester, find.text('Load more'));
      expect(find.text('Future service'), findsOneWidget);
      expect(find.text('Next page service'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'document resubmission uses requirement ID and requires explicit submit',
    (tester) async {
      final backend = OverviewBackend();
      final f = await overview(tester, backend);
      f.requirementBody = [
        requirementJson(
          id: 7,
          type: 'DOCUMENT_UPLOAD',
          status: 'REJECTED',
          value: {
            'files': [
              {'key': 'customers/12/documents/record.pdf'},
            ],
          },
        ),
      ];
      await press(tester, find.text('Upload / resubmit').first);
      expect(find.text('View document 1'), findsOneWidget);
      expect(
        f.f.adapter.requests.where(
          (r) =>
              r.method == 'PUT' && r.path.endsWith('/requirement-submissions'),
        ),
        isEmpty,
      );
      await press(tester, find.text('Submit documents'));
      final writes = f.f.adapter.requests
          .where(
            (r) =>
                r.method == 'PUT' &&
                r.path.endsWith('/requirement-submissions'),
          )
          .toList();
      expect(writes, hasLength(1));
      expect(
        ((writes.single.data as Map)['submissions'] as List)
            .single['requirementId'],
        7,
      );
      expect(
        ((writes.single.data as Map)['submissions'] as List)
            .single['requirementId'],
        isNot(55),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'profile footer Home returns to Home instead of staying selected',
    (tester) async {
      await overview(tester, OverviewBackend());
      await tester.tap(find.byKey(const ValueKey('customer-nav-home')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('customer-home-account')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('invalid overview statistics and invalid contact input fail without contact writes', () async {
    final f = BookingFixture();
    await f.start();
    addTearDown(f.dispose);
    final backend = OverviewBackend();
    backend.install(f);
    final repo = CustomerProfileOverviewRepository(f.journey.repository);
    (backend.data['statistics'] as Map)['pendingCount'] = -1;
    await expectLater(repo.overview(), throwsFormatException);
    await expectLater(
      repo.contact('phone', '0771234567'),
      throwsA(isA<ContactProblem>()),
    );
    expect(backend.otpWrites, 0);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/features/auth/application/customer_auth_controller.dart';
import 'package:customer_app/features/booking/application/customer_booking_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_request_payment_widget_test.dart' show ready;

class RatingBackend {
  bool rated = false, failRead = false, unknownWrite = false;
  int writes = 0;
  Completer<void>? gate;
  Map<String, dynamic> saved = {};
  Map<String, dynamic> get view => {
    'jobId': 70,
    'jobStatus': 'COMPLETED',
    'canRate': !rated,
    'providers': [
      {
        'providerId': 18,
        'displayName': 'Kumari Perera',
        'profilePhoto': null,
        'rated': rated,
        'rating': rated ? saved : null,
      },
    ],
  };
  void install(BookingFixture f) {
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path == '/auth/logout') {
        return ResponseBody.fromString('', 204);
      }
      if (r.path.endsWith('/bookings/70/ratings')) {
        if (r.method == 'POST') {
          writes++;
          await gate?.future;
          if (unknownWrite) {
            throw const NetworkException(
              kind: NetworkExceptionKind.timeout,
              message: 'Timeout',
            );
          }
          saved = {
            'jobId': 70,
            'providerId': 18,
            'rating': (r.data as Map)['rating'],
            'comment': (r.data as Map)['comment'],
          };
          rated = true;
          return ResponseBody.fromString(
            jsonEncode(saved),
            201,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromString(
          jsonEncode(failRead ? {'detail': 'Unavailable'} : view),
          failRead ? 503 : 200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return previous(r);
    };
  }
}

Future<BookingFixture> openRating(
  WidgetTester tester,
  RatingBackend backend, {
  String status = 'COMPLETED',
}) async {
  final f = await ready(tester);
  backend.install(f);
  f.bookings = [
    {
      ...bookingJson(
        id: 70,
        method: 'WALLET',
        payment: status == 'COMPLETED' ? 'SETTLED' : 'RESERVED',
      ),
      'status': status,
    },
  ];
  f.requestViewBody.addAll({
    'status': status,
    'paymentStatus': status == 'COMPLETED' ? 'SETTLED' : 'RESERVED',
  });
  ProviderScope.containerOf(tester.element(find.byType(CustomerApp)))
      .invalidate(customerBookingHistoryProvider(12));
  await tester.tap(find.byKey(const ValueKey('customer-nav-opportunities')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Booking #70').last);
  await tester.pumpAndSettle();
  if (status == 'COMPLETED') {
    await tester.ensureVisible(
      backend.rated && !backend.failRead
          ? find.byKey(const ValueKey('saved-rating-4'))
          : find.text(backend.failRead ? 'Rate your provider' : 'Add a Review'),
    );
  }
  await tester.pumpAndSettle();
  return f;
}

Future<void> chooseRating(WidgetTester tester) async {
  final entry = find.text('Add a Review').evaluate().isNotEmpty
      ? find.text('Add a Review')
      : find.text('Kumari Perera');
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
  final star = find.byKey(const ValueKey('rating-star-5'));
  await tester.ensureVisible(star);
  await tester.tap(star);
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('submit-provider-rating')),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('new completion opens review sheet once without submitting', (
    tester,
  ) async {
    final backend = RatingBackend();
    final f = await openRating(
      tester,
      backend,
      status: 'AWAITING_COMPLETION_CONFIRMATION',
    );
    expect(find.byKey(const ValueKey('booking-rating-sheet')), findsNothing);
    f.bookings = [
      {...f.bookings.single, 'status': 'COMPLETED', 'paymentStatus': 'SETTLED'},
    ];
    f.requestViewBody['status'] = 'COMPLETED';
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Rate the Service'), findsOneWidget);
    expect(backend.writes, 0);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('submit-provider-rating')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Close review'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('booking-rating-sheet')), findsNothing);
    expect(backend.writes, 0);
    expect(find.text('Add a Review'), findsOneWidget);
    await tester.ensureVisible(find.text('Add a Review'));
    await tester.tap(find.text('Add a Review'));
    await tester.pumpAndSettle();
    expect(find.text('Rate the Service'), findsOneWidget);
    expect(backend.writes, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'review sheet fits large text and logout removes account details without posting',
    (tester) async {
      final backend = RatingBackend();
      await openRating(tester, backend);
      await chooseRating(tester);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final auth = ProviderScope.containerOf(
        tester.element(find.byType(CustomerApp)),
      ).read(customerAuthControllerProvider);
      final logout = auth.logout();
      await tester.pumpAndSettle();
      await logout;
      expect(auth.user, isNull, reason: auth.error);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('booking-rating-sheet')), findsNothing);
      expect(find.text('Kumari Perera'), findsNothing);
      expect(backend.writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'completed details submits explicit rating once and keeps saved feedback',
    (tester) async {
      final backend = RatingBackend();
      final f = await openRating(tester, backend);
      expect(backend.writes, 0);
      await chooseRating(tester);
      backend.gate = Completer<void>();
      final submit = find.byKey(const ValueKey('submit-provider-rating'));
      await tester.tap(submit);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(submit);
      await tester.pump(const Duration(milliseconds: 200));
      expect(backend.writes, 1);
      backend.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('saved-rating-5')), findsOneWidget);
      expect(submit, findsNothing);
      expect(
        f.f.adapter.requests.where(
          (r) =>
              r.method == 'POST' &&
              !r.path.endsWith('/ratings') &&
              r.path.contains('/bookings/'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unreadable rating state offers read retry without submission', (
    tester,
  ) async {
    final backend = RatingBackend()..failRead = true;
    await openRating(tester, backend);
    expect(find.text('Check rating status'), findsOneWidget);
    expect(backend.writes, 0);
    backend.failRead = false;
    await tester.ensureVisible(find.text('Check rating status'));
    await tester.tap(find.text('Check rating status'));
    await tester.pumpAndSettle();
    expect(find.text('Add a Review'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'unknown submission and failed reconciliation blocks repeat writes',
    (tester) async {
      final backend = RatingBackend();
      await openRating(tester, backend);
      await chooseRating(tester);
      backend.unknownWrite = true;
      backend.failRead = true;
      await tester.tap(find.byKey(const ValueKey('submit-provider-rating')));
      await tester.pumpAndSettle();
      expect(backend.writes, 1);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('submit-provider-rating')),
      );
      expect(button.onPressed, isNull);
      await tester.pump(const Duration(seconds: 15));
      expect(backend.writes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'already rated provider has no editor and narrow large text fits',
    (tester) async {
      final backend = RatingBackend()
        ..rated = true
        ..saved = {'rating': 4};
      await openRating(tester, backend);
      expect(find.byKey(const ValueKey('saved-rating-4')), findsOneWidget);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('submit-provider-rating')),
        findsNothing,
      );
      expect(backend.writes, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('repository rejects invalid rating locally before any write', () async {
    final f = BookingFixture();
    await f.start();
    addTearDown(f.dispose);
    for (final stars in [0, 6]) {
      await expectLater(
        f.journey.repository.rateProvider(70, 18, stars, ''),
        throwsFormatException,
      );
    }
    await expectLater(
      f.journey.repository.rateProvider(70, 18, 5, 'a' * 1001),
      throwsFormatException,
    );
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/ratings')),
      isEmpty,
    );
  });
}

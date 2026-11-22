import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/auth/application/customer_auth_controller.dart';
import 'package:customer_app/features/booking/application/customer_booking_controller.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_provider_details_dialog.dart';
import 'package:customer_app/features/booking/presentation/customer_provider_reviews.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'provider_reviews_fixture.dart';

Future<void> open(WidgetTester tester, ReviewsBackend backend) async {
  final f = BookingFixture();
  await tester.runAsync(f.start);
  backend.install(f);
  addTearDown(f.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerAuthControllerProvider.overrideWithValue(f.f.controller),
        customerBookingRepositoryProvider.overrideWithValue(
          f.journey.repository,
        ),
      ],
      child: MaterialApp(
        theme: CustomerTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBookingProviderDetails(
                context,
                ProviderCandidate(candidateJson()),
                feedback: const CustomerProviderReviews(
                  providerId: 15,
                  optionId: 12,
                ),
              ),
              child: const Text('View provider'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('View provider'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'profile reviews show rating distribution, page and switch scope without closing',
    (tester) async {
      final backend = ReviewsBackend();
      await open(tester, backend);
      expect(find.text('Ratings & reviews'), findsOneWidget);
      expect(find.text('2 ratings · Hospital Care'), findsOneWidget);
      expect(find.text('Helpful service 41'), findsOneWidget);
      await tapVisible(tester, find.text('Load more reviews'));
      expect(find.text('Helpful service 42'), findsOneWidget);
      expect(find.text('Load more reviews'), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('review-scope-all')));
      expect(find.text('4 ratings · All services'), findsOneWidget);
      expect(find.text('Helpful service 42'), findsNothing);
      expect(
        find.byKey(const ValueKey('booking-provider-details-dialog')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'unrated empty state fits narrow large text and closes normally',
    (tester) async {
      final backend = ReviewsBackend()..empty = true;
      await open(tester, backend);
      expect(find.text('Not yet rated'), findsOneWidget);
      expect(find.text('No reviews yet for this selection.'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('booking-provider-details-close')),
      );
      expect(
        find.byKey(const ValueKey('booking-provider-details-dialog')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'unavailable endpoints keep profile open and retries recover independently',
    (tester) async {
      final backend = ReviewsBackend()
        ..summaryFails = true
        ..reviewsFail = true;
      await open(tester, backend);
      expect(find.text('Retry summary'), findsOneWidget);
      expect(find.text('Retry reviews'), findsOneWidget);
      backend.summaryFails = false;
      backend.reviewsFail = false;
      await tapVisible(tester, find.text('Retry summary'));
      await tapVisible(tester, find.text('Retry reviews'));
      expect(find.text('Helpful service 41'), findsOneWidget);
      expect(find.text('2 ratings · Hospital Care'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

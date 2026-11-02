import 'customer_test_map.dart';

import 'dart:async';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:customer_app/features/booking/application/customer_booking_controller.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_location_picker.dart';
import 'package:customer_app/features/booking/presentation/customer_booking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_auth_test.dart' show optionJson;

import 'package:customer_app/features/booking/presentation/booking_validation_group.dart';

import 'customer_discovery_test.dart' show marketEntry, continueMarket;

Future<void> openBooking(WidgetTester tester, BookingFixture f) async {
  f.install();
  await marketEntry(tester, f.f);
  await continueMarket(tester);
  await tester.ensureVisible(find.byKey(const ValueKey('customer-service-3')));
  await tester.tap(find.byKey(const ValueKey('customer-service-3')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('customer-option-12')));
  await tester.tap(find.byKey(const ValueKey('customer-option-12')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Continue with this service'));
  await tester.tap(find.text('Continue with this service'));
  await tester.pumpAndSettle();
}

CustomerBookingController activeJourney(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(CustomerBookingScreen)),
    ).read(customerBookingProvider(const BookingKey(1, 3, 12)));

Future<void> applyBookingFilters(WidgetTester tester) async {
  final c = activeJourney(tester);
  c.edit(() {
    c.languages.add('ENGLISH');
    for (final skill in c.context!.skills) {
      c.skills.add(skill['skillId'] as int);
    }
    for (final field in c.context!.providerFilters) {
      c.providerFilters[field.id] = switch (field.type) {
        'BOOLEAN' => false,
        'NUMBER' => {'minimum': 0},
        _ => [field.options.first['value']!],
      };
    }
    c.start = '2030-01-07T08:00:00';
    c.end = '2030-01-07T10:00:00';
    c.point ??= const GeoPoint(6.9271, 79.8612);
    if (c.address.isEmpty) c.address = 'Test customer address';
  });
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('booking-location-continue')),
  );
  await tester.tap(find.byKey(const ValueKey('booking-location-continue')));
  await tester.pumpAndSettle();
}

Future<void> advanceToServiceDetails(WidgetTester tester) async {
  await applyBookingFilters(tester);
  final c = activeJourney(tester);
  if (c.stage == BookingStage.results) {
    for (final candidate in c.candidates) {
      if (!c.selected.containsKey(candidate.id)) c.select(candidate);
      if (c.selected.length == c.context!.providerCount) break;
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-results-continue')));
    await tester.pumpAndSettle();
  }
  expect(c.stage, BookingStage.serviceDetails);
}

void main() {
  testWidgets(
    'matching polls the backend and provider acceptance never auto-charges or invents auto-approval',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      c.created = {...f.requestViewBody, 'paymentMethod': 'WALLET'};
      c.stage = BookingStage.created;
      await tester.runAsync(c.refreshCreatedRequest);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('booking-finding-provider')),
        findsOneWidget,
      );
      f.requestViewBody.addAll({
        'status': 'AWAITING_CUSTOMER_CONFIRMATION',
        'providerId': 15,
        'confirmationExpiresAt': c
            .now()
            .add(const Duration(minutes: 2))
            .toUtc()
            .toIso8601String(),
      });
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('booking-provider-accepted')),
        findsOneWidget,
      );
      expect(find.text('We found a provider!'), findsOneWidget);
      expect(find.text('Provider 15'), findsOneWidget);
      expect(find.textContaining('Auto-approve'), findsNothing);
      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
        isEmpty,
      );
      await tester.ensureVisible(find.text('View request details'));
      await tester.tap(find.text('View request details'));
      await tester.pumpAndSettle();
      expect(find.text('Request #501'), findsOneWidget);
    },
  );
  testWidgets(
    'wallet decline shows the failure illustration and retry reaches verified success',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      final c = activeJourney(tester);
      f.requestViewBody['status'] = 'AWAITING_CUSTOMER_CONFIRMATION';
      f.walletConfirmationStatus = 409;
      c.created = {...f.requestViewBody, 'paymentMethod': 'WALLET'};
      c.stage = BookingStage.created;
      await tester.runAsync(c.confirmRequestWallet);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-payment-failed')),
        findsOneWidget,
      );
      expect(find.text('Payment Failed!'), findsOneWidget);
      expect(
        find.text('Insufficient available wallet balance'),
        findsOneWidget,
      );
      expect(find.text('Payment Successful!'), findsNothing);
      f.walletConfirmationStatus = 200;
      final retry = find.byKey(const ValueKey('payment-result-retry'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(
        find.text(
          'Your booking is confirmed. Wallet funds have been reserved.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('View booking'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-payment-success')),
        findsNothing,
      );
      expect(find.text('Request #501'), findsOneWidget);
    },
  );
  testWidgets(
    'blocked payment and app resume keep the booking review draft instead of returning to filters',
    (tester) async {
      final f = BookingFixture();
      f.contextBody = contextJson(
        selectionMode: 'OPEN_REQUEST',
        methods: ['CARD'],
      );
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      c.note = 'Keep my booking details';
      c.review();
      await tester.pumpAndSettle();
      final start = c.start;
      final end = c.end;
      final searchResult = c.searchResult;
      final contextRequests = f.f.adapter.requests
          .where((r) => r.path.startsWith('/customers/me/booking-context'))
          .length;
      final create = find.byKey(const ValueKey('booking-create'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Payments are not enabled for this service yet. Please contact support.',
        ),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(c.stage, BookingStage.review);
      expect(c.start, start);
      expect(c.end, end);
      expect(c.note, 'Keep my booking details');
      expect(c.searchResult, same(searchResult));
      expect(c.created, isNull);
      expect(
        f.f.adapter.requests
            .where((r) => r.path.startsWith('/customers/me/booking-context'))
            .length,
        contextRequests,
      );
      expect(
        find.byKey(const ValueKey('booking-review-summary')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'unavailable Open estimate is retryable and never shown as zero cost',
    (tester) async {
      final f = BookingFixture();
      f.contextBody = contextJson(selectionMode: 'OPEN_REQUEST');
      f.estimateStatus = 404;
      f.estimateBody = {'detail': 'No estimate available'};
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      expect(
        find.text('A price estimate is not available for this service yet.'),
        findsOneWidget,
      );
      expect(find.text('Rs. 0.00'), findsNothing);
      expect(activeJourney(tester).stage, BookingStage.serviceDetails);
      f.estimateStatus = 200;
      f.estimateBody = {'expectedAmount': 3200, 'currencyCode': 'LKR'};
      final retry = find.byTooltip('Retry estimate');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Rs. 3,200.00'), findsOneWidget);
      expect(
        find.text('Cost available after provider acceptance.'),
        findsNothing,
      );
      expect(activeJourney(tester).selected, isEmpty);
      expect(activeJourney(tester).created, isNull);
    },
  );
  testWidgets(
    'details automatically estimates the selected interval and discards stale quotes',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      expect(find.text('Estimated cost'), findsOneWidget);
      expect(find.text('Rs. 2,400.00'), findsOneWidget);
      final request = f.f.adapter.requests.lastWhere(
        (r) => r.path.endsWith('/bookings/quote'),
      );
      expect((request.data as Map)['startDatetime'], c.start);
      expect((request.data as Map)['expectedEndDatetime'], c.end);
      final wait = Completer<void>();
      f.pendingQuote = wait;
      c.edit(() => c.note = 'First change');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.text('Rs. 2,400.00'), findsNothing);
      f.pendingQuote = null;
      f.quoteBody = {'expectedAmount': 3300, 'currencyCode': 'LKR'};
      c.edit(() => c.note = 'Latest change');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Rs. 3,300.00'), findsOneWidget);
      wait.complete();
      await tester.pumpAndSettle();
      expect(find.text('Rs. 3,300.00'), findsOneWidget);
      expect(c.busy, isFalse);
      expect(c.stage, BookingStage.serviceDetails);
      expect(c.created, isNull);
    },
  );

  testWidgets(
    'open request estimates before acceptance without provider, payment method or booking answers',
    (tester) async {
      final f = BookingFixture();
      f.contextBody = contextJson(
        selectionMode: 'OPEN_REQUEST',
        fields: [fieldJson(id: 20, code: 'PERSON_NAME', type: 'TEXT')],
      );
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      expect(find.text('Rs. 3,000.00'), findsOneWidget);
      expect(activeJourney(tester).selected, isEmpty);
      final c = activeJourney(tester);
      expect(c.answers, isEmpty);
      expect(c.method, isNull);
      final request = f.f.adapter.requests.singleWhere(
        (r) => r.path.endsWith('/bookings/estimate'),
      );
      final payload = request.data as Map;
      final booking = payload['booking'] as Map;
      expect(payload['marketId'], 1);
      expect(booking['startDatetime'], c.start);
      expect(booking['expectedEndDatetime'], c.end);
      expect(booking['pricingSelections'], isEmpty);
      expect(booking.containsKey('providerId'), isFalse);
      expect(booking.containsKey('providerIds'), isFalse);
      expect(booking.containsKey('answers'), isFalse);
      expect(booking.containsKey('paymentMethod'), isFalse);
      expect(c.created, isNull);

      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/bookings/quote')),
        isEmpty,
      );
    },
  );
  testWidgets(
    'review keeps the map read-only and payment choices reachable with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      c.review();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CustomerTestMap>(find.byType(CustomerTestMap))
            .state
            .onSelect,
        isNull,
      );
      await tester.ensureVisible(find.text('Cash on Hand'));
      await tester.pumpAndSettle();
      expect(find.text('Cash on Hand'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-create')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'hot reload preserves the booking review draft and selected provider',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      c.note = 'Keep this draft after reload';
      c.review();
      await tester.pumpAndSettle();
      final selected = c.selected.keys.toList();
      final reload = tester.binding.reassembleApplication();
      await tester.pump();
      await reload;
      await tester.pumpAndSettle();
      expect(activeJourney(tester), same(c));
      expect(c.stage, BookingStage.review);
      expect(c.note, 'Keep this draft after reload');
      expect(c.selected.keys, selected);
      expect(
        find.byKey(const ValueKey('booking-review-summary')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'card payment opens Add Card only when the saved-card list is empty',
    (tester) async {
      final f = BookingFixture()..hasSavedCard = false;
      f.contextBody = contextJson(methods: ['CARD']);
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      c.review();
      await tester.pumpAndSettle();
      final create = find.byKey(const ValueKey('booking-create'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text('Select Payment Method'), findsOneWidget);
      expect(find.text('No saved cards yet.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('booking-add-new-card')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Close add card'), findsOneWidget);
      expect(c.created, isNull);
      await tester.tap(find.byTooltip('Close add card'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'existing saved card is reused when CARD is chosen after an unset payment method',
    (tester) async {
      final f = BookingFixture();
      f.contextBody = contextJson(methods: ['CARD', 'CASH']);
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      c.method = null;
      c.review();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Credit / Debit Card'));
      await tester.tap(find.text('Credit / Debit Card'));
      await tester.pumpAndSettle();
      final create = find.byKey(const ValueKey('booking-create'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text('Select Payment Method'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-saved-card-5')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('booking-use-selected-card')));
      await tester.pumpAndSettle();
      expect(find.text('Add New Card'), findsNothing);
      expect(
        find.byKey(const ValueKey('booking-payment-confirmation')),
        findsOneWidget,
      );
      expect(c.method, 'CARD');
      expect(c.created, isNull);
      expect(
        f.f.adapter.requests.where(
          (r) => r.path.contains('/payment-methods/setup'),
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'review without a payment method opens payment choices instead of adding another card',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      c.method = null;
      c.review();
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('booking-create'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Choose a payment method'), findsOneWidget);
      expect(find.text('Add New Card'), findsNothing);
      expect(c.stage, BookingStage.review);
      expect(c.created, isNull);
    },
  );
  testWidgets(
    'provider results use a read-only map and draggable list with sticky selection action',
    (tester) async {
      final f = BookingFixture();
      f.candidateRows = [
        candidateJson(),
        candidateJson(id: 16),
        candidateJson(id: 17),
      ];
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      await tester.runAsync(c.search);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-providers-sheet')),
        findsOneWidget,
      );
      expect(find.text('Available providers nearby'), findsOneWidget);
      expect(find.text('3 providers'), findsOneWidget);
      final footer = find.byKey(const ValueKey('booking-results-continue'));
      expect(tester.widget<FilledButton>(footer).onPressed, isNull);
      final map = tester
          .widget<CustomerTestMap>(find.byType(CustomerTestMap))
          .state;
      expect(map.onSelect, isNull);
      expect(
        map.markers.where((m) => m.markerId.value.startsWith('provider-')),
        hasLength(3),
      );
      map.markers
          .firstWhere(
            (m) => m.markerId.value == 'provider-${c.candidates.first.key}',
          )
          .onTap!();
      await tester.pumpAndSettle();
      expect(c.selected.keys, [15]);
      expect(find.text('Selected'), findsOneWidget);
      expect(tester.widget<FilledButton>(footer).onPressed, isNotNull);
      await tester.tap(footer);
      await tester.pumpAndSettle();
      expect(c.stage, BookingStage.serviceDetails);
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-find-providers')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-find-providers')));
      await tester.pumpAndSettle();
      expect(c.stage, BookingStage.review);
    },
  );

  testWidgets(
    'provider results remain usable on narrow displays with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      await tester.runAsync(activeJourney(tester).search);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Provider 15'));
      await tester.tap(find.text('Provider 15'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-results-continue')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'service requirements can be submitted and refreshed before provider search',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.f.autoAvailability = true;
      f.requirementBody = [requirementJson()];
      f.eligibility = {'eligible': false, 'reasons': []};
      await openBooking(tester, f);
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Additional information'), findsOneWidget);
      expect(
        find.text('Please complete this detail · needed for this service'),
        findsOneWidget,
      );
      final input = find.byKey(const ValueKey('booking-input-requirement-1'));
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Home care detail');
      await tester.pumpAndSettle();
      f.requirementBody = [
        requirementJson(value: 'Home care detail', status: 'PENDING'),
      ];
      await tester.ensureVisible(find.text('Save requirement changes'));
      await tester.tap(find.text('Save requirement changes'));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).error, isNull);
      expect(activeJourney(tester).requirements.single.status, 'PENDING');
      expect(activeJourney(tester).allowed, isFalse);
      f.requirementBody = [
        requirementJson(value: 'Home care detail', status: 'APPROVED'),
      ];
      f.eligibility = {'eligible': true, 'reasons': []};
      await tester.ensureVisible(
        find.text('Check review / refresh requirements'),
      );
      await tester.tap(find.text('Check review / refresh requirements'));
      await tester.pumpAndSettle();
      expect(find.text('Choose location and time'), findsOneWidget);
      expect(activeJourney(tester).stage, BookingStage.serviceDetails);
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
        isEmpty,
      );
      await tester.ensureVisible(find.text('Choose location and time'));
      await tester.tap(find.text('Choose location and time'));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).stage, BookingStage.details);
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'filter count updates before Continue without leaving filter screen',
    (tester) async {
      final f = BookingFixture();
      f.f.autoAvailability = true;
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final c = activeJourney(tester);
      expect(c.stage, BookingStage.details);
      expect(find.text('1 provider available'), findsOneWidget);
      f.candidateRows = [];
      c.edit(() => c.radius = 12);
      await tester.pump();
      expect(find.text('Checking providers…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('No providers available'), findsOneWidget);
      expect(c.stage, BookingStage.details);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'eligibility denial opens requirements without showing unverified booking questions',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody = contextJson(fields: [fieldJson(id: 70, type: 'TEXT')]);
      f.eligibility = {'eligible': false, 'reasons': []};
      f.searchStatus = 403;
      f.searchError = {
        'message': 'Complete your customer requirements.',
        'eligibility': f.eligibility,
      };
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      expect(find.byKey(const ValueKey('booking-field-70')), findsNothing);
      expect(find.text('Refresh access'), findsOneWidget);
      expect(find.text('Check available providers'), findsOneWidget);
      expect(activeJourney(tester).availability, isNull);
    },
  );

  testWidgets(
    'available count and provider pins appear on the booking form map',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody = contextJson(
        fields: [
          for (var i = 0; i < 8; i++)
            fieldJson(id: 80 + i, code: 'QUESTION_$i'),
        ],
      );
      f.candidateRows = [candidateJson(id: 15), candidateJson(id: 16)];
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      expect(find.text('2 providers available'), findsOneWidget);
      final badge = find.byKey(const ValueKey('booking-availability-count'));
      final panel = find
          .descendant(
            of: find.byKey(const ValueKey('booking-details-sheet')),
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.getRect(badge).bottom,
        lessThanOrEqualTo(tester.getRect(panel).top),
      );
      final map = tester.widget<CustomerTestMap>(find.byType(CustomerTestMap));
      expect(
        map.state.markers.where(
          (m) => m.markerId.value.startsWith('provider-'),
        ),
        hasLength(2),
      );
      expect(map.state.circles.single.radius, 5000);
    },
  );

  testWidgets(
    'empty availability shows a clear message and stays on the filter form',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.candidateRows = [];
      await openBooking(tester, f);
      final c = activeJourney(tester);
      c.edit(() {
        c.languages.add('ENGLISH');
        c.skills.add(10);
        c.address = 'Test service address';
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('booking-location-continue')));
      await tester.pumpAndSettle();
      expect(c.stage, BookingStage.details);
      expect(find.text('No matching providers just yet'), findsOneWidget);
      expect(find.text('No providers available'), findsOneWidget);
      expect(c.error, isNull);
      expect(
        find.byKey(const ValueKey('booking-availability-notice')),
        findsOneWidget,
      );
      c.edit(() => c.radius = 12);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-availability-notice')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('booking-find-providers')),
        findsNothing,
      );
    },
  );

  for (final serviceDetails in [false, true]) {
    testWidgets(
      'service dropdown changes option inside ${serviceDetails ? 'Service Details' : 'location/time'} and preserves common selections',
      (tester) async {
        final f = BookingFixture();
        addTearDown(f.f.dispose);
        f.f.adapter.optionBodies['1/3'] = [
          optionJson(),
          optionJson(id: 13, name: 'Hospital Care'),
        ];
        final next = contextJson(
          fields: [
            {
              ...fieldJson(id: 77, code: 'HOSPITAL', type: 'TEXT'),
              'optionId': 13,
              'optionIds': [13],
              'label': 'Hospital name',
            },
          ],
        );
        (next['selection'] as Map)['option']['optionId'] = 13;
        (next['selection'] as Map)['option']['name'] = 'Hospital Care';
        (next['bookingSchema'] as Map)['options'][0]['optionId'] = 13;
        f.optionContexts[13] = next;
        await openBooking(tester, f);
        final old = activeJourney(tester);
        old.edit(() {
          old.point = const GeoPoint(7.48, 80.36);
          old.address = 'Kurunegala, Sri Lanka';
          old.start = '2030-01-07T08:00:00';
          old.end = '2030-01-07T10:00:00';
        });
        if (serviceDetails) await advanceToServiceDetails(tester);
        f.candidateRows = [
          {...candidateJson(), 'optionId': 13},
        ];
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('booking-service-selector')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Choose service category'), findsNothing);
        expect(find.text('Hospital Care'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('booking-service-option-13')),
        );
        await tester.pumpAndSettle();
        final screen = tester.widget<CustomerBookingScreen>(
          find.byType(CustomerBookingScreen),
        );
        final current = ProviderScope.containerOf(
          tester.element(find.byType(CustomerBookingScreen)),
        ).read(customerBookingProvider(screen.bookingKey));
        expect(current.key.optionId, 13);
        expect(current.point?.latitude, 7.48);
        expect(current.address, 'Kurunegala, Sri Lanka');
        expect(current.start, '2030-01-07T08:00:00');
        expect(
          current.stage,
          serviceDetails ? BookingStage.results : BookingStage.details,
        );
        if (serviceDetails) {
          current.select(current.candidates.first);
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('booking-results-continue')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('booking-field-77')),
            findsOneWidget,
          );
        }
        expect(find.text('Choose service category'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a booking field added by Admin appears when continuing to Service Details',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      f.contextBody = contextJson(
        fields: [
          {
            ...fieldJson(id: 70, code: 'NEW_ADMIN_FIELD', type: 'TEXT'),
            'label': 'New admin question',
          },
        ],
      );
      await advanceToServiceDetails(tester);
      expect(find.byKey(const ValueKey('booking-field-70')), findsOneWidget);
      expect(find.text('New admin question'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Patient name hides help text and required markers while backend validation remains',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody = contextJson(
        fields: [
          {
            ...fieldJson(
              id: 20,
              code: 'PATIENT_NAME',
              type: 'TEXT',
              required: true,
            ),
            'label': 'Patient name',
            'description': 'Patient help text',
          },
          {
            ...fieldJson(id: 21, code: 'INSTRUCTIONS', type: 'TEXTAREA'),
            'label': 'Instructions',
            'description': 'Backend instruction help',
          },
        ],
      );
      (f.contextBody['selection'] as Map)['option']['responsibilities'] = [
        {'title': 'Bring equipment', 'responsibleParty': 'CUSTOMER'},
      ];
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      expect(find.text('Patient help text'), findsNothing);
      expect(find.text('Patient name'), findsOneWidget);
      expect(find.text('Patient name *'), findsNothing);
      expect(find.text('Instructions'), findsOneWidget);
      expect(find.text('Instructions *'), findsNothing);
      expect(find.text('Backend instruction help'), findsOneWidget);
      expect(find.text('Responsibilities'), findsNothing);
      expect(find.text('Bring equipment'), findsNothing);
      expect(find.text('Estimated duration'), findsNothing);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.byTooltip('Change service location'), findsNothing);
    },
  );

  testWidgets(
    'Service Details matches expanded form with sticky Continue, inline errors and typed choice tiles',
    (tester) async {
      tester.view.physicalSize = const Size(393, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      final floor = fieldJson(
        id: 22,
        code: 'FLOOR',
        type: 'SELECT',
        required: true,
      );
      floor['options'] = [
        {'value': 0, 'label': 'Ground floor'},
        {'value': 1, 'label': 'Upper floor'},
      ];
      f.contextBody = contextJson(
        fields: [
          fieldJson(id: 20, code: 'ROOM', type: 'TEXT', required: true),
          fieldJson(id: 21, code: 'LIFT', type: 'BOOLEAN', required: true),
          floor,
        ],
      );
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final button = find.byKey(const ValueKey('booking-find-providers'));
      expect(button.hitTestable(), findsOneWidget);
      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byKey(const ValueKey('booking-details-sheet')),
      );
      expect(sheet.controller!.size, closeTo(sheet.maxChildSize, .001));
      await tester.tap(button);
      await tester.pumpAndSettle();
      final c = activeJourney(tester);
      expect(c.stage, BookingStage.serviceDetails);
      expect(
        c.fieldErrors.keys,
        containsAll([
          'service-field-20',
          'service-field-21',
          'service-field-22',
        ]),
      );
      expect(
        tester
            .widget<BookingValidationGroup>(
              find.byKey(const ValueKey('service-field-validation-20')),
            )
            .error,
        isNotNull,
      );
      expect(
        find.text('Complete the highlighted details to continue.'),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('booking-input-field-20')),
        'Ward A',
      );
      await tester.pumpAndSettle();
      for (final label in ['No', 'Ground floor']) {
        final tile = find.widgetWithText(OutlinedButton, label);
        await Scrollable.ensureVisible(tester.element(tile), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      expect(c.answers['ROOM'], 'Ward A');
      expect(c.answers['LIFT'], false);
      expect(c.answers['FLOOR'], 0);
      expect(c.fieldErrors, isEmpty);
      expect(button.hitTestable(), findsOneWidget);
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty preferences show errors and keep the customer on location/time',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody['providerFilters'] = [
        {
          'fieldId': 52,
          'label': 'Gender',
          'fieldType': 'SELECT',
          'filterOperator': 'IN',
          'options': ['MALE', 'FEMALE'],
        },
      ];
      await openBooking(tester, f);
      await tester.tap(find.byKey(const ValueKey('booking-location-continue')));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).stage, BookingStage.details);
      expect(
        find.text('Choose at least one option to continue.'),
        findsOneWidget,
      );
      expect(find.text('Choose at least one language.'), findsOneWidget);
      expect(
        find.text('Complete the highlighted details to continue.'),
        findsNothing,
      );
      final genderGroup = find.byKey(
        const ValueKey('provider-filter-validation-52'),
      );
      expect(
        tester.widget<BookingValidationGroup>(genderGroup).error,
        isNotNull,
      );
      final invalidFrame = tester.widget<Container>(
        find
            .descendant(of: genderGroup, matching: find.byType(Container))
            .first,
      );
      expect((invalidFrame.decoration as BoxDecoration).border, isNotNull);
      await Scrollable.ensureVisible(
        tester.element(find.text('English')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BookingValidationGroup>(
              find.byKey(const ValueKey('booking-language-validation')),
            )
            .error,
        isNull,
      );
      expect(
        tester.widget<BookingValidationGroup>(genderGroup).error,
        isNotNull,
      );
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
        isEmpty,
      );
      await advanceToServiceDetails(tester);
      expect(
        find.text('Complete the highlighted details to continue.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'language choices remain selectable without a heading and expansion fits content',
    (tester) async {
      tester.view.physicalSize = const Size(393, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody['providerFilters'] = [
        {
          'fieldId': 48,
          'label': 'Spoken languages',
          'fieldType': 'MULTI_SELECT',
          'filterOperator': 'IN',
          'options': ['SINHALA', 'ENGLISH', 'TAMIL'],
        },
      ];
      await openBooking(tester, f);
      expect(find.text('Spoken languages'), findsNothing);
      final english = find.text('ENGLISH');
      await tester.ensureVisible(english);
      await tester.tap(english);
      await tester.pumpAndSettle();
      expect(activeJourney(tester).providerFilters[48], ['ENGLISH']);
      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byKey(const ValueKey('booking-details-sheet')),
      );
      expect(sheet.maxChildSize, lessThan(.94));
      sheet.controller!.jumpTo(sheet.maxChildSize);
      await tester.pumpAndSettle();
      final scroll = tester.widget<SingleChildScrollView>(
        find
            .descendant(
              of: find.byKey(const ValueKey('booking-details-sheet')),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      expect(scroll.controller!.position.maxScrollExtent, closeTo(0, 1));
      await tester.tap(english);
      await tester.pumpAndSettle();
      expect(activeJourney(tester).providerFilters.containsKey(48), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'location form opens expanded, keeps Continue visible and collapses on drag',
    (tester) async {
      tester.view.physicalSize = const Size(393, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byKey(const ValueKey('booking-details-sheet')),
      );
      expect(sheet.initialChildSize, sheet.maxChildSize);
      expect(sheet.controller!.size, closeTo(sheet.maxChildSize, .001));
      final button = find.byKey(const ValueKey('booking-location-continue'));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(850));
      expect(tester.getRect(button).width, greaterThan(340));
      final initial = tester
          .getRect(find.byKey(const ValueKey('booking-choose-location')))
          .top;
      await tester.drag(
        find.byKey(const ValueKey('booking-choose-location')),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byKey(const ValueKey('booking-choose-location')))
            .top,
        greaterThan(initial),
      );
      expect(sheet.controller!.size, lessThan(sheet.maxChildSize));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(850));
      expect(find.byType(RangeSlider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review displays only configured pricing fields and server quote amount',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody['providerFilters'] = [
        {
          'fieldId': 45,
          'label': 'Care level',
          'fieldType': 'SELECT',
          'filterOperator': 'IN',
          'options': ['BASIC', 'SPECIALIST'],
        },
        {
          'fieldId': 47,
          'label': 'Gender',
          'fieldType': 'SELECT',
          'filterOperator': 'IN',
          'options': ['MALE', 'FEMALE'],
        },
      ];
      f.contextBody['pricingFieldIds'] = [45];
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      final c = activeJourney(tester);
      await tester.runAsync(() => c.search());
      c.select(c.candidates.single);
      c.review();
      await tester.pumpAndSettle();
      expect(find.text('Care level (pricing)'), findsOneWidget);
      expect(find.text('Gender (pricing)'), findsNothing);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SPECIALIST').last);
      await tester.pumpAndSettle();
      expect(c.pricingSelections, {45: 'SPECIALIST'});
      await tester.ensureVisible(find.byKey(const ValueKey('booking-quote')));
      await tester.tap(find.byKey(const ValueKey('booking-quote')));
      await tester.pumpAndSettle();
      expect(find.text('Estimated total'), findsOneWidget);
      expect(find.text('Rs. 2,400.00'), findsOneWidget);
      c.choosePricing(45, 'BASIC');
      await tester.pumpAndSettle();
      expect(find.text('Rs. 2,400.00'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Service Details uses the map panel and only the configured fields with real schedule summary',
    (tester) async {
      tester.view.physicalSize = const Size(393, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody = contextJson(
        fields: [
          fieldJson(id: 20, code: 'ROOM_CODE', type: 'TEXT'),
          fieldJson(id: 21, code: 'UNIT_CODE', type: 'NUMBER'),
        ],
      );
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      expect(
        find.byKey(const ValueKey('booking-details-sheet')),
        findsOneWidget,
      );
      expect(find.byType(CustomerTestMap), findsOneWidget);
      expect(find.text('Service details'), findsNothing);
      expect(find.text('Ward number'), findsNothing);
      expect(find.text('Bed number'), findsNothing);
      final first = find.byKey(const ValueKey('service-detail-card-20'));
      final second = find.byKey(const ValueKey('service-detail-card-21'));
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester.getTopLeft(first).dx,
        lessThan(tester.getTopLeft(second).dx),
      );
      expect(find.text('Scheduled for'), findsOneWidget);
      expect(find.text('2 hours'), findsOneWidget);
      expect(find.text('23 providers available'), findsNothing);
      expect(find.text('Test customer address'), findsOneWidget);
      expect(find.byTooltip('Change service location'), findsNothing);
      expect(find.text('Estimated duration'), findsNothing);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Additional notes (optional)'), findsNothing);
      expect(find.byKey(const ValueKey('service-customer-note')), findsNothing);
      expect(activeJourney(tester).stage, BookingStage.serviceDetails);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).stage, BookingStage.results);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'calendar selects a date outside the quick choices and preserves time range',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      final c = activeJourney(tester);
      c.edit(() {
        c.start = '2030-01-07T08:00:00';
        c.end = '2030-01-07T10:00:00';
      });
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-calendar')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-calendar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(c.start, '2030-01-20T08:00:00');
      expect(c.end, '2030-01-20T10:00:00');
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.textContaining('Selected date:'), findsOneWidget);
    },
  );
  testWidgets(
    'single start slider preserves overnight duration and supports custom duration',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      final c = activeJourney(tester);
      c.edit(() => c.start = '2030-01-07T08:00:00');
      await tester.pumpAndSettle();
      var slider = tester.widget<Slider>(
        find.byKey(const ValueKey('booking-start-time')),
      );
      slider.onChanged!(1380);
      await tester.pumpAndSettle();
      expect(c.start, '2030-01-07T23:00:00');
      expect(c.end, '2030-01-08T05:00:00');
      await tester.ensureVisible(find.text('Custom'));
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('booking-custom-hours')),
        '1.5',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(c.end, '2030-01-08T00:30:00');
      slider = tester.widget<Slider>(
        find.byKey(const ValueKey('booking-start-time')),
      );
      expect(
        DateTime.parse(c.end).difference(DateTime.parse(c.start)).inMinutes,
        90,
      );
    },
  );
  testWidgets(
    'route schedule has pickup-only time and no invented end or duration',
    (tester) async {
      final f = BookingFixture();
      f.contextBody = contextJson(schedule: 'ROUTE_BASED');
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      expect(find.byKey(const ValueKey('booking-start-time')), findsNothing);
      expect(find.text('Duration'), findsNothing);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('booking-pickup-time')),
      );
      expect(slider.onChanged, isNotNull);
      slider.onChanged!(600);
      await tester.pumpAndSettle();
      expect(activeJourney(tester).start, endsWith('T10:00:00'));
      expect(activeJourney(tester).end, isEmpty);
    },
  );
  testWidgets(
    'radius control updates the displayed search circle and fits the map',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      final c = activeJourney(tester);
      c.edit(() => c.point = const GeoPoint(6.9271, 79.8612));
      await tester.pumpAndSettle();
      final oldZoom = tester
          .widget<CustomerTestMap>(find.byType(CustomerTestMap))
          .state
          .camera
          .zoom;
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-radius-picker')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-radius-picker')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('booking-radius')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      expect(c.radius, greaterThan(5));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CustomerTestMap>(find.byType(CustomerTestMap))
            .state
            .circles
            .single
            .radius,
        c.radius * 1000,
      );
      expect(
        tester
            .widget<CustomerTestMap>(find.byType(CustomerTestMap))
            .state
            .camera
            .zoom,
        lessThan(oldZoom),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'location and service questions are separate screens with preserved answers on Back',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody = contextJson(fields: [fieldJson(required: true)]);
      await openBooking(tester, f);
      expect(find.byKey(const ValueKey('booking-field-20')), findsNothing);
      expect(find.text('Provider comes to me'), findsNothing);
      expect(find.text('Enter location coordinates'), findsNothing);
      expect(find.text('Latitude'), findsNothing);
      await advanceToServiceDetails(tester);
      expect(activeJourney(tester).stage, BookingStage.serviceDetails);
      expect(find.byKey(const ValueKey('booking-field-20')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-radius')), findsNothing);
      final c = activeJourney(tester);
      c.answer(c.context!.fields.single, 'Patient details');
      await tester.pumpAndSettle();
      expect(c.stage, BookingStage.serviceDetails);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).stage, BookingStage.results);
      expect(c.answers.values, contains('Patient details'));
      expect(
        f.f.adapter.requests.where(
          (r) => r.path == '/customers/me/provider-search',
        ),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'location button opens a real map picker without coordinate fields',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-choose-location')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-choose-location')));
      await tester.pumpAndSettle();
      expect(find.text('Latitude'), findsNothing);
      expect(find.text('Longitude'), findsNothing);
      final map = find.byType(CustomerTestMap).last;
      await tester.tapAt(tester.getCenter(map));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Address or landmark'), findsNothing);
      await tester.ensureVisible(find.text('Use this location'));
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).point?.valid, isTrue);
      expect(activeJourney(tester).address, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '15-minute start slider preserves duration and duration presets derive end time',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      final c = activeJourney(tester);
      c.edit(() {
        c.start = '2030-01-07T08:00:00';
        c.end = '2030-01-07T10:00:00';
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('booking-start')), findsNothing);
      expect(find.byKey(const ValueKey('booking-end')), findsNothing);
      var slider = tester.widget<Slider>(
        find.byKey(const ValueKey('booking-start-time')),
      );
      slider.onChanged!(555);
      await tester.pumpAndSettle();
      expect(c.start, '2030-01-07T09:15:00');
      expect(c.end, '2030-01-07T11:15:00');
      await tester.ensureVisible(find.text('6h'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6h'));
      await tester.pumpAndSettle();
      slider = tester.widget<Slider>(
        find.byKey(const ValueKey('booking-start-time')),
      );
      expect(slider.value, 555);
      expect(c.end, '2030-01-07T15:15:00');
      await tester.ensureVisible(find.text('2d'));
      await tester.tap(find.text('2d'));
      await tester.pumpAndSettle();
      slider = tester.widget<Slider>(
        find.byKey(const ValueKey('booking-start-time')),
      );
      expect(
        DateTime.parse(c.end).difference(DateTime.parse(c.start)).inMinutes,
        2880,
      );
      expect(c.end, '2030-01-09T09:15:00');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'gender tiles show configured choices and remain separate from booking answers',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody['providerFilters'] = [
        {
          'fieldId': 25,
          'label': 'Gender preference',
          'fieldType': 'SELECT',
          'filterOperator': 'IN',
          'options': [
            {'value': 'MALE', 'label': 'Male'},
            {'value': 'FEMALE', 'label': 'Female'},
          ],
        },
      ];
      await openBooking(tester, f);
      expect(
        find.byKey(const ValueKey('booking-details-sheet')),
        findsOneWidget,
      );
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      await tester.ensureVisible(find.text('Female'));
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).providerFilters[25], ['FEMALE']);
      expect(activeJourney(tester).answers, isEmpty);
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).providerFilters[25], ['MALE']);
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).providerFilters.containsKey(25), isFalse);
      expect(find.text('Sinhala'), findsOneWidget);
      expect(find.text('23 providers nearby'), findsNothing);
    },
  );
  testWidgets('duration shortcuts update the existing market-local schedule', (
    tester,
  ) async {
    final f = BookingFixture();
    addTearDown(f.f.dispose);
    await openBooking(tester, f);
    final c = activeJourney(tester);
    c.edit(() {
      c.start = '2030-01-07T08:00:00';
      c.end = '2030-01-07T10:00:00';
    });
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('6h')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('6h'));
    await tester.pumpAndSettle();
    expect(c.end, '2030-01-07T14:00:00');
    expect(tester.takeException(), isNull);
  });
  setUpAll(() async {
    await (FontLoader(
      'Public Sans',
    )..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'))).load();
  });
  testWidgets(
    'sub-service enters details, real provider selection, review, booking and history',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      expect(activeJourney(tester).stage, BookingStage.details);
      expect(find.byType(CustomerTestMap), findsOneWidget);
      final journey = activeJourney(tester);
      journey.edit(() {
        journey.start = '2030-01-07T08:00:00';
        journey.end = '2030-01-07T10:00:00';
        journey.point = const GeoPoint(6.9271, 79.8612);
        journey.address = 'Test customer address';
      });
      await tester.pumpAndSettle();
      await applyBookingFilters(tester);

      expect(find.text('Choose your provider'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Choose your provider')).dy,
        greaterThan(200),
      );
      expect(find.text('Not yet rated'), findsOneWidget);
      await tester.ensureVisible(find.text('Provider 15'));
      await tester.tap(find.text('Provider 15'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-results-continue')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-results-continue')));
      await tester.pumpAndSettle();
      expect(journey.stage, BookingStage.serviceDetails);
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-find-providers')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-find-providers')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-review-summary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('booking-review-summary')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(journey.stage, BookingStage.serviceDetails);
      expect(journey.selected.keys, [15]);
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-find-providers')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-find-providers')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('booking-create')));
      await tester.tap(find.byKey(const ValueKey('booking-create')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('booking-confirm-and-pay')));
      await tester.pumpAndSettle();
      expect(find.text('Booking recorded'), findsOneWidget);
      expect(find.textContaining('Payment: PENDING'), findsOneWidget);
      expect(find.text('Payment Successful!'), findsNothing);
      await tester.ensureVisible(find.text('My bookings'));
      await tester.tap(find.text('My bookings'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nursing #100'), findsOneWidget);
    },
  );
  testWidgets(
    'backend conditional fields appear and disappear without hardcoded service names',
    (tester) async {
      final f = BookingFixture();
      f.contextBody = contextJson(
        fields: [
          fieldJson(id: 1, code: 'HOSPITAL', type: 'BOOLEAN'),
          fieldJson(
            id: 2,
            code: 'WARD',
            condition: {'fieldCode': 'HOSPITAL', 'value': true},
          ),
        ],
      );
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      await advanceToServiceDetails(tester);
      expect(find.text('WARD'), findsNothing);
      await tester.ensureVisible(find.text('Yes'));
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('WARD'), findsOneWidget);
      await tester.ensureVisible(find.text('No'));
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(find.text('WARD'), findsNothing);
    },
  );
  testWidgets('ineligible customer sees review reasons and cannot search', (
    tester,
  ) async {
    final f = BookingFixture();
    f.requirementBody = [
      requirementJson(value: 'Test detail', status: 'PENDING'),
    ];
    f.eligibility = {
      'eligible': false,
      'reasons': [
        {'code': 'PENDING', 'message': 'Waiting for document review'},
      ],
    };
    addTearDown(f.f.dispose);
    await openBooking(tester, f);
    await advanceToServiceDetails(tester);
    expect(find.text('Waiting for document review'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('booking-find-providers')),
    );
    expect(
      tester
          .widget<BThereButton>(
            find.byKey(const ValueKey('booking-find-providers')),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('large text and narrow screens keep dynamic details reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final f = BookingFixture();
    addTearDown(f.f.dispose);
    await openBooking(tester, f);
    await advanceToServiceDetails(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('booking-find-providers')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'validation hints appear beside invalid location and schedule controls',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      activeJourney(tester).edit(() {
        activeJourney(tester).point = null;
        activeJourney(tester).start = '';
        activeJourney(tester).end = '';
      });
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-location-continue')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-location-continue')));
      await tester.pumpAndSettle();
      final error = find.text('Choose where you need the service.');
      expect(error, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('booking-location-validation')),
          matching: error,
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<BookingValidationGroup>(
              find.byKey(const ValueKey('booking-schedule-validation')),
            )
            .error,
        isNotNull,
      );
      expect(
        find.text('Complete the highlighted details to continue.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'schedule shows friendly dates and the whole field opens the picker',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      await openBooking(tester, f);
      activeJourney(tester)
          .edit(() => activeJourney(tester).start = '2030-01-07T08:00:00');
      await tester.pumpAndSettle();
      expect(find.text('2030-01-07T08:00:00'), findsNothing);
      expect(find.textContaining('Selected date:'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-calendar')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-calendar')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(activeJourney(tester).start, '2030-01-07T08:00:00');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'location permission failure retains map pin selection and attribution',
    (tester) async {
      GeoPoint? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
            customerDeviceLocationProvider.overrideWithValue(
              () async => throw const BookingProblem(
                'Permission denied; choose a pin.',
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookingLocationPicker(
                  point: null,
                  onChanged: (p) => selected = p,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Use current location'));
      await tester.pumpAndSettle();
      expect(find.text('Permission denied; choose a pin.'), findsOneWidget);
      expect(find.text('Latitude'), findsNothing);
      expect(find.text('Longitude'), findsNothing);
      await tester.tapAt(tester.getCenter(find.byType(CustomerTestMap)));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(selected?.valid, isTrue);
      expect(find.byType(CustomerTestMap), findsOneWidget);
    },
  );
}

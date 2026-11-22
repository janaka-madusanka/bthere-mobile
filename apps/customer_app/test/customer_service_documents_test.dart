import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_booking_widget_test.dart' show openBooking, activeJourney;
import 'customer_profile_overview_test.dart'
    show overview, OverviewBackend, press;

Map<String, dynamic> certificate(String status) {
  final row = requirementJson(
    id: 7,
    type: 'DOCUMENT_UPLOAD',
    status: status,
    value: status == 'MISSING'
        ? null
        : {
            'files': [
              {'key': 'customers/12/documents/test.pdf'},
            ],
          },
  );
  final definition = row['requirement']['definition'] as Map;
  definition.addAll(<String, Object?>{
    'label': 'Service certificate',
    'minimumFiles': 1,
    'maximumFiles': 2,
    'maximumFileSizeMb': 10,
    'allowedFileTypes': ['PDF', 'JPG', 'PNG', 'WEBP'],
  });
  return row;
}

void main() {
  testWidgets(
    'missing required document opens gate before filters and provider search',
    (tester) async {
      final f = BookingFixture()..autoAvailability = true;
      addTearDown(f.f.dispose);
      f.requirementBody = [certificate('MISSING')];
      f.eligibility = {'eligible': false, 'reasons': []};
      await openBooking(tester, f);
      expect(find.text('Documents needed before booking'), findsOneWidget);
      expect(find.text('Service certificate'), findsOneWidget);
      expect(find.text('Not submitted'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-location-continue')),
        findsNothing,
      );
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
        isEmpty,
      );
      await press(tester, find.text('Upload / resubmit'));
      expect(find.text('Upload document'), findsOneWidget);
      await press(tester, find.text('Close'));
      expect(find.text('Documents needed before booking'), findsOneWidget);
      expect(
        f.f.adapter.requests.where(
          (r) =>
              r.method == 'PUT' && r.path.endsWith('/requirement-submissions'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'rejected document resubmits explicitly, pending is read-only, approval returns to booking',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.requirementBody = [certificate('REJECTED')];
      f.eligibility = {'eligible': false, 'reasons': []};
      await openBooking(tester, f);
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.method == 'PUT' && r.path.endsWith('/requirement-submissions')) {
          f.requirementBody = [certificate('PENDING')];
        }
        return previous(r);
      };
      expect(find.text('Please correct the evidence'), findsOneWidget);
      await press(tester, find.text('Upload / resubmit'));
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await press(tester, find.text('Submit documents'));
      expect(find.text('Under review'), findsOneWidget);
      expect(
        f.f.adapter.requests.where(
          (r) =>
              r.method == 'PUT' && r.path.endsWith('/requirement-submissions'),
        ),
        hasLength(1),
      );
      await press(tester, find.text('View documents'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit documents'),
            )
            .onPressed,
        isNull,
      );
      await press(tester, find.text('Close'));
      expect(activeJourney(tester).allowed, isFalse);
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
        isEmpty,
      );
      // The document gate and both upload/read-only sheets were checked at 2x.
      // Return to the normal viewport before testing the separate booking form.
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      f.requirementBody = [certificate('APPROVED')];
      f.eligibility = {'eligible': true, 'reasons': []};
      await press(tester, find.text('Check review status'));
      expect(find.text('Documents needed before booking'), findsNothing);
      expect(activeJourney(tester).allowed, isTrue);
      expect(
        find.byKey(const ValueKey('booking-location-continue')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Profile can discover never-submitted option documents by service scope',
    (tester) async {
      final backend = OverviewBackend();
      backend.data['documents'] = [];
      final f = await overview(tester, backend);
      f.requirementBody = [certificate('MISSING')];
      f.eligibility = {'eligible': false, 'reasons': []};
      await press(
        tester,
        find.byKey(const ValueKey('profile-add-service-documents')),
      );
      await press(
        tester,
        find.byKey(const ValueKey('profile-document-service')),
      );
      await press(tester, find.text('Nursing').last);
      await press(
        tester,
        find.byKey(const ValueKey('profile-document-option-3')),
      );
      await press(tester, find.text('Home Care').last);
      expect(find.text('Service certificate'), findsOneWidget);
      expect(find.text('Not submitted'), findsOneWidget);
      final reads = f.f.adapter.requests
          .where((r) => Uri.parse(r.path).path == '/customers/me/requirements')
          .toList();
      expect(reads.last.uri.queryParameters['serviceTypeId'], '3');
      expect(reads.last.uri.queryParameters['optionId'], '12');
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('context denial still exposes document requirements; all blocked states remain blocked', () async {
    final f = BookingFixture();
    await f.start();
    addTearDown(f.dispose);
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (Uri.parse(r.path).path == '/customers/me/booking-context') {
        return ResponseBody.fromString(
          jsonEncode({
            'detail': 'Customer requirements must be completed before booking',
          }),
          403,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return previous(r);
    };
    for (final status in ['MISSING', 'PENDING', 'REJECTED', 'EXPIRED']) {
      f.requirementBody = [certificate(status)];
      f.eligibility = {'eligible': false, 'reasons': []};
      f.journey.context = null;
      await f.journey.load();
      expect(f.journey.needsServiceDocuments, isTrue);
      expect(f.journey.allowed, isFalse);
      expect(() => f.journey.searchInput(), throwsA(isA<BookingProblem>()));
    }
    expect(
      f.f.adapter.requests.where(
        (r) => r.method == 'POST' && r.path.contains('booking'),
      ),
      isEmpty,
    );
  });
}

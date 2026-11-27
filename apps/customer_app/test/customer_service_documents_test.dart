import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/data/customer_booking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_discovery_test.dart' show marketEntry, continueMarket;
import 'customer_profile_overview_test.dart' show press;

Future<void> openBooking(WidgetTester tester, BookingFixture f) async {
  f.install();
  await marketEntry(tester, f.f);
  await continueMarket(tester);
  await press(tester, find.byKey(const ValueKey('customer-service-3')));
  await press(tester, find.byKey(const ValueKey('customer-option-12')));
}

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
  test(
    'schema upload formats constrain picker and exclude PDF from images',
    () {
      final row = certificate('MISSING');
      (row['requirement']['definition'] as Map)['allowedFileTypes'] = ['PDF'];
      expect(CustomerRequirement.parse(row).field.uploadExtensions, ['pdf']);
      final image = certificate('MISSING');
      (image['requirement']['definition'] as Map).addAll(<String, Object?>{
        'fieldType': 'IMAGE_UPLOAD',
        'allowedFileTypes': [],
      });
      final field = CustomerRequirement.parse(image).field;
      expect(field.supportedUploadTypes, ['JPG', 'PNG', 'WEBP']);
      expect(field.uploadExtensions, contains('jpeg'));
      expect(field.uploadExtensions, isNot(contains('pdf')));
    },
  );

  test('private document view refreshes a signed URL and validates returned identity', () async {
    final f = BookingFixture();
    addTearDown(f.f.dispose);
    f.install();
    await f.f.service.login('test', 'password');
    final repository = CustomerBookingRepository(f.f.service);
    const key = 'customers/12/documents/a b+.pdf';
    await repository.view(key);
    await repository.view(key);
    final reads = f.f.adapter.requests
        .where((r) => r.path.startsWith('/uploads/view-url'))
        .toList();
    expect(reads.length, 2);
    expect(reads.last.uri.queryParameters['key'], key);
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path.startsWith('/uploads/view-url')) {
        return ResponseBody.fromString(
          jsonEncode({
            'key': 'different-file',
            'url': 'https://example.invalid/file',
            'expiresAt': '2030-01-01T00:10:00Z',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return previous(r);
    };
    await expectLater(repository.view(key), throwsFormatException);
  });

  testWidgets(
    'document sheet shows schema limits, rejection and optional expiry calendar',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      final row = certificate('REJECTED');
      (row['requirement']['definition'] as Map).addAll(<String, Object?>{
        'allowedFileTypes': ['PDF'],
        'maximumFiles': 1,
        'maximumFileSizeMb': 2,
      });
      f.requirementBody = [row];
      f.eligibility = {'eligible': false, 'reasons': []};
      await openBooking(tester, f);
      expect(
        find.byKey(const ValueKey('document-review-status')),
        findsOneWidget,
      );
      expect(
        find.text('Allowed formats: PDF. Maximum 2 MB per file.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Upload document'),
            )
            .onPressed,
        isNull,
      );
      final expiry = find.byKey(const ValueKey('document-expiry-date'));
      expect(tester.widget<TextField>(expiry).readOnly, isTrue);
      await press(tester, expiry);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await press(tester, find.text('OK'));
      expect(tester.widget<TextField>(expiry).controller!.text, isNotEmpty);
      await press(tester, find.byTooltip('Clear expiry date'));
      expect(tester.widget<TextField>(expiry).controller!.text, isEmpty);
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

  for (final status in ['MISSING', 'PENDING', 'REJECTED']) {
    testWidgets('blocked $status service opens Profile document UI directly', (
      tester,
    ) async {
      final f = BookingFixture()..autoAvailability = true;
      addTearDown(f.f.dispose);
      f.requirementBody = [certificate(status)];
      f.eligibility = {'eligible': false, 'reasons': []};
      await openBooking(tester, f);
      expect(find.text('Profile'), findsNothing);
      expect(find.text('My documents'), findsNothing);
      expect(find.text('Continue with this service'), findsNothing);
      expect(find.text('Documents required'), findsNothing);
      expect(find.text('Documents needed before booking'), findsNothing);
      expect(
        find.byKey(const ValueKey('booking-location-continue')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('document-review-status')),
        findsOneWidget,
      );
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
        isEmpty,
      );
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/booking-context')),
        isEmpty,
      );
      expect(
        f.f.adapter.requests.where(
          (r) => r.path == '/customers/me/documents/7',
        ),
        hasLength(1),
      );
      await press(tester, find.text('Close'));
      expect(
        find.byKey(const ValueKey('document-review-status')),
        findsNothing,
      );
      expect(find.text('Get a Service'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

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

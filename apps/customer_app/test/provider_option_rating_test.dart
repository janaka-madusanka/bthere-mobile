import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_provider_results_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderCandidate candidate(Map<String, dynamic> extra) =>
    ProviderCandidate.parse({
      'providerId': 15,
      'assignmentId': 10,
      'displayName': 'Nethmi Perera',
      'remainingCapacity': 1,
      'averageRating': 4.9,
      'totalRatings': 120,
      'languages': ['ENGLISH'],
      ...extra,
    });

Future<void> card(WidgetTester tester, Map<String, dynamic> extra) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CustomerTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BookingProviderCard(
            candidate: candidate(extra),
            serviceName: 'Hospital Care',
            selected: false,
            onTap: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('search uses service rating rather than overall rating', (
    tester,
  ) async {
    await card(tester, {'optionAverageRating': 4.2, 'optionTotalRatings': 8});
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('(8)'), findsOneWidget);
    expect(find.text('For Hospital Care'), findsOneWidget);
    expect(find.text('4.9'), findsNothing);
    expect(find.text('(120)'), findsNothing);
  });
  testWidgets('unrated option never borrows an overall rating', (tester) async {
    await card(tester, {'optionAverageRating': null, 'optionTotalRatings': 0});
    expect(find.text('Not yet rated'), findsOneWidget);
    expect(find.text('For Hospital Care'), findsOneWidget);
    expect(find.text('4.9'), findsNothing);
    expect(find.text('(0)'), findsNothing);
  });
  testWidgets('older responses label overall rating honestly', (tester) async {
    await card(tester, {});
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('(120)'), findsOneWidget);
    expect(find.text('Overall rating'), findsOneWidget);
    expect(find.text('For Hospital Care'), findsNothing);
  });
  testWidgets('service scope and rating fit narrow large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await card(tester, {
      'optionAverageRating': 4.2,
      'optionTotalRatings': 1000,
    });
    expect(tester.takeException(), isNull);
  });
  test('option rating parser rejects malformed scores/counts', () {
    for (final value in [-1, 0, 6, double.nan, double.infinity, '4.2']) {
      expect(
        () => candidate({'optionAverageRating': value}),
        throwsFormatException,
      );
    }
    for (final value in [-1, 1.5, '8']) {
      expect(
        () => candidate({'optionTotalRatings': value}),
        throwsFormatException,
      );
    }
    final overall = candidate({
      'optionAverageRating': null,
      'optionTotalRatings': 0,
    });
    expect(overall.data['averageRating'], 4.9);
    expect(overall.searchRating, isNull);
  });
}

import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_chat_test.dart' show page, jsonResponse;
import 'customer_booking_rating_test.dart' show RatingBackend, openRating;

class ProvidersBackend extends RatingBackend {
  String status = 'COMPLETED';
  bool chatSend = true;
  DateTime? chatUntil;
  @override
  void install(BookingFixture f) {
    super.install(f);
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path.endsWith('/messages')) {
        return jsonResponse({
          ...page(send: chatSend),
          'jobId': 70,
          'sendUntil': chatUntil?.toIso8601String(),
        });
      }
      if (r.path.endsWith('/bookings/70/providers')) {
        return ResponseBody.fromString(
          jsonEncode({
            'jobId': 70,
            'providers': [
              {
                'providerId': 18,
                'displayName': 'Assigned Nurse',
                'role': 'PRIMARY',
                'profilePhoto': null,
                'averageRating': 4.5,
                'totalRatings': 12,
                'ratedByYou': true,
                'contact': {
                  'callAllowed': true,
                  'phoneNumber': '0771234567',
                  'unavailableReason': null,
                },
              },
              {
                'providerId': 19,
                'displayName': 'Team Nurse',
                'role': 'TEAM_MEMBER',
                'profilePhoto': null,
                'averageRating': 0,
                'totalRatings': 0,
                'ratedByYou': false,
                'contact': {
                  'callAllowed': false,
                  'phoneNumber': '0770000000',
                  'unavailableReason': 'PHONE_NOT_AVAILABLE',
                },
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return previous(r);
    };
  }
}

void main() {
  testWidgets(
    'completed details loads assigned team and hides phone even with stale server permission',
    (tester) async {
      final f = await openRating(tester, ProvidersBackend());
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-assigned-providers')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Assigned Nurse'), findsOneWidget);
      expect(find.text('Team Nurse'), findsOneWidget);
      expect(find.text('0771234567'), findsNothing);
      expect(find.text('0770000000'), findsNothing);
      expect(find.byTooltip('Call provider'), findsNothing);
      await tester.tap(find.text('Assigned Nurse'));
      await tester.pumpAndSettle();
      expect(find.text('Provider Details'), findsOneWidget);
      expect(find.text('4.5 (12 reviews)'), findsOneWidget);
      expect(find.text('Verified'), findsNothing);
      expect(find.text('0771234567'), findsNothing);
      expect(find.byTooltip('Call provider'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assigned-provider-details-sheet')),
        findsNothing,
      );

      expect(
        f.f.adapter.requests.where(
          (r) => r.path.endsWith('/providers') && r.method != 'GET',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'confirmed booking exposes only authorized provider phone and fits large text',
    (tester) async {
      await openRating(tester, ProvidersBackend(), status: 'CONFIRMED');
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-assigned-providers')),
      );
      await tester.pumpAndSettle();
      expect(find.text('0771234567'), findsOneWidget);
      expect(find.byTooltip('Call provider'), findsOneWidget);
      expect(find.byTooltip('Message provider'), findsNWidgets(2));
      expect(find.text('0770000000'), findsNothing);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final expired in [false, true]) {
    testWidgets(
      'unavailable chat hides booking message buttons (expired=$expired)',
      (tester) async {
        await openRating(
          tester,
          ProvidersBackend()
            ..chatSend = expired
            ..chatUntil = expired
                ? DateTime.utc(2020)
                : null,
          status: 'CONFIRMED',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('booking-assigned-providers')),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Message provider'), findsNothing);
        expect(find.text('Assigned Nurse'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

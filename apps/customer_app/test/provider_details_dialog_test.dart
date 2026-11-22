import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_provider_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderCandidate candidate() => ProviderCandidate.parse({
  'providerId': 15,
  'assignmentId': 10,
  'displayName': 'Nethmi Perera',
  'remainingCapacity': 1,
  'averageRating': 4.8,
  'totalRatings': 124,
  'languages': ['ENGLISH', 'SINHALA'],
  'distanceKm': .4,
});

void main() {
  testWidgets(
    'search-only profile does not fabricate biography, skills, jobs or reviews',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CustomerTheme.light(),
          home: BookingProviderDetailsDialog(candidate: candidate()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nethmi Perera'), findsOneWidget);
      expect(find.text('(124 ratings)'), findsOneWidget);
      expect(find.text('Languages'), findsOneWidget);
      expect(find.text('About Me'), findsNothing);
      expect(find.text('Skills'), findsNothing);
      expect(find.text('Previous Work'), findsNothing);
      expect(find.textContaining('jobs'), findsNothing);
      expect(find.textContaining('Verified'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full public profile scrolls at large text while close remains reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: CustomerTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showBookingProviderDetails(
                  context,
                  candidate(),
                  details: const ProviderProfileDetails(
                    about: 'Reliable caregiver providing personal care and daily living support.',
                    experienceYears: 3,
                    location: 'Colombo, Sri Lanka',
                    skills: [
                      'Elderly Care',
                      'Personal Care',
                      'Mobility Assistance',
                    ],
                    reviews: [
                      ProviderWorkReview(
                        name: 'Anjali P.',
                        rating: 5,
                        text: 'Kind and attentive.',
                        date: '12 Aug 2026',
                      ),
                    ],
                  ),
                ),
                child: const Text('Open profile'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Kind and attentive.'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Previous Work'), findsOneWidget);
      final close = find.byKey(
        const ValueKey('booking-provider-details-close'),
      );
      expect(tester.getBottomRight(close).dy, lessThanOrEqualTo(640));
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-provider-details-dialog')),
        findsNothing,
      );
    },
  );
}

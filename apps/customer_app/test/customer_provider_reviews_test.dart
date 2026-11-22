import 'dart:async';

import 'package:customer_app/features/booking/application/customer_provider_reviews_controller.dart';
import 'package:customer_app/features/booking/domain/provider_reviews.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'provider_reviews_fixture.dart';

void main() {
  late BookingFixture f;
  late ReviewsBackend backend;
  late CustomerProviderReviewsController c;
  setUp(() async {
    f = BookingFixture();
    await f.start();
    backend = ReviewsBackend()..install(f);
    c = CustomerProviderReviewsController(
      f.journey.repository,
      f.f.controller,
      15,
      12,
    );
  });
  tearDown(() {
    c.dispose();
    f.dispose();
  });
  test(
    'loads overall and option summary, pages scoped reviews using GET only',
    () async {
      await Future.wait([c.loadSummary(), c.loadReviews()]);
      expect(c.summaries.map((s) => s.optionId), [null, 12, 13]);
      expect(c.reviews.single.optionId, 12);
      expect(c.hasMore, isTrue);
      await c.loadReviews();
      expect(c.reviews.map((r) => r.id), [41, 42]);
      expect(c.hasMore, isFalse);
      expect(backend.pages, [0, 1]);
      expect(
        f.f.adapter.requests
            .where((r) => r.path.contains('/providers/15/'))
            .every((r) => r.method == 'GET'),
        isTrue,
      );
    },
  );
  test('failed next page keeps prior reviews and retries same page', () async {
    await c.loadReviews();
    backend.reviewsFail = true;
    await c.loadReviews();
    expect(c.reviews.single.id, 41);
    expect(c.reviewError, isNotNull);
    backend.reviewsFail = false;
    await c.loadReviews();
    expect(backend.pages, [0, 1, 1]);
    expect(c.reviews.length, 2);
  });
  test(
    'late old scope and duplicate loading cannot contaminate selected reviews',
    () async {
      backend.gate = Completer<void>();
      backend.started = Completer<void>();
      final gate = backend.gate!;
      final first = c.loadReviews();
      await backend.started!.future;
      await c.loadReviews();
      expect(backend.calls, 1);
      await c.select(13);
      gate.complete();
      await first;
      expect(c.optionId, 13);
      expect(c.reviews.single.optionId, 13);
      expect(c.nextPage, 1);
    },
  );
  test(
    'logout drops delayed data without later notifications or extra requests',
    () async {
      backend.gate = Completer<void>();
      backend.started = Completer<void>();
      final gate = backend.gate!;
      final read = c.loadReviews();
      await backend.started!.future;
      await f.f.controller.logout();
      gate.complete();
      await read;
      expect(c.alive, isFalse);
      expect(c.reviews, isEmpty);
      await c.loadReviews();
      expect(backend.calls, 1);
    },
  );
  test(
    'summary failure is independent from reviews and read retry recovers',
    () async {
      backend.summaryFails = true;
      await Future.wait([c.loadSummary(), c.loadReviews()]);
      expect(c.summaryError, isNotNull);
      expect(c.reviews.length, 1);
      backend.summaryFails = false;
      await c.loadSummary();
      expect(c.summaryError, isNull);
      expect(c.summaries.length, 3);
    },
  );
  test('invalid rating summary or review cannot fabricate public feedback', () {
    expect(
      () => ProviderRatingSummary.parse({
        ...summaryJson(2),
        'averageRating': double.nan,
      }),
      throwsFormatException,
    );
    expect(
      () => ProviderRatingSummary.parse({
        ...summaryJson(2),
        'distribution': {'5': -1},
      }),
      throwsFormatException,
    );
    expect(
      () => ProviderReview.parse({...reviewJson(41), 'rating': 6}),
      throwsFormatException,
    );
    expect(
      () =>
          ProviderReview.parse({...reviewJson(41), 'createdAt': 'not a date'}),
      throwsFormatException,
    );
    expect(
      ProviderReview.parse({...reviewJson(41), 'comment': null}).comment,
      isNull,
    );
    expect(ProviderRatingSummary.parse(summaryJson(0)).average, isNull);
  });
}

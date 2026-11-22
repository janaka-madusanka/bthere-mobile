import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';

import 'booking_fixture.dart';

Map<String, dynamic> summaryJson(int count, {int? option}) => {
  'optionId': ?option,
  if (option != null)
    'optionName': option == 12 ? 'Hospital Care' : 'Home Care',
  'averageRating': count == 0 ? null : 4.5,
  'totalRatings': count,
  'distribution': {
    '1': 0,
    '2': 0,
    '3': 0,
    '4': count ~/ 2,
    '5': count - count ~/ 2,
  },
};
Map<String, dynamic> reviewJson(int id, {int option = 12}) => {
  'ratingId': id,
  'optionId': option,
  'optionName': option == 12 ? 'Hospital Care' : 'Home Care',
  'rating': 5,
  'comment': 'Helpful service $id',
  'customerName': 'Nimali S.',
  'createdAt': '2026-11-10T09:30:00',
};

class ReviewsBackend {
  bool summaryFails = false, reviewsFail = false, empty = false;
  int calls = 0;
  Completer<void>? gate, started;
  final List<int> pages = [];
  void install(BookingFixture f) {
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path == '/customers/me/providers/15/ratings') {
        return response(
          summaryFails
              ? {'detail': 'Unavailable'}
              : {
                  'providerId': 15,
                  'displayName': 'Nethmi Perera',
                  'overall': summaryJson(empty ? 0 : 4),
                  'options': [
                    summaryJson(empty ? 0 : 2, option: 12),
                    summaryJson(2, option: 13),
                  ],
                },
          summaryFails ? 503 : 200,
        );
      }
      if (r.uri.path.endsWith('/customers/me/providers/15/reviews')) {
        calls++;
        final page = int.parse(r.uri.queryParameters['page']!);
        final option = int.tryParse(r.uri.queryParameters['optionId'] ?? '');
        pages.add(page);
        final wait = gate;
        gate = null;
        if (wait != null) {
          started?.complete();
          await wait.future;
        }
        return response(
          reviewsFail
              ? {'detail': 'Unavailable'}
              : {
                  'content': empty
                      ? []
                      : [reviewJson(page == 0 ? 41 : 42, option: option ?? 13)],
                  'number': page,
                  'size': 10,
                  'totalPages': empty ? 0 : 2,
                  'totalElements': empty ? 0 : 2,
                },
          reviewsFail ? 503 : 200,
        );
      }
      return previous(r);
    };
  }

  ResponseBody response(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

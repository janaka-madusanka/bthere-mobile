import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart' show Fixture;
import 'customer_discovery_test.dart' show marketEntry, continueMarket;

void main() {
  testWidgets(
    'Home loads public banners for selected market and opens service options',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.extraHandler = (request) async {
        if (request.path != '/markets/1/banners') return null;
        return ResponseBody.fromString(
          jsonEncode({
            'marketId': 1,
            'banners': [
              {
                'bannerId': 4,
                'title': 'Care offer',
                'imageUrl': 'https://example.com/offer.png',
                'linkType': 'SERVICE',
                'serviceTypeId': 3,
              },
            ],
          }),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
      };
      await marketEntry(tester, f);
      await continueMarket(tester);
      expect(find.bySemanticsLabel('Care offer'), findsOneWidget);
      final request = f.adapter.requests.singleWhere(
        (r) => r.path == '/markets/1/banners',
      );
      expect(request.queryParameters, {'audience': 'CUSTOMER'});
      expect(request.extra['bthere.network.requires_auth'], false);
      await tester.tap(find.bySemanticsLabel('Care offer'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customer-option-12')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

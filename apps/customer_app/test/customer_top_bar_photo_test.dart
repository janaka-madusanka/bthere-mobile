import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:customer_app/app/widgets/customer_top_bar.dart';
import 'package:customer_app/features/profile/application/customer_profile_controller.dart';

import 'booking_fixture.dart';
import 'customer_auth_test.dart' show customerProfileJson;
import 'customer_discovery_test.dart' show marketEntry, continueMarket;

void main() {
  testWidgets(
    'all main tabs use the profile controller photo and react to removal',
    (tester) async {
      final f = BookingFixture();
      f.install();
      addTearDown(f.f.dispose);
      f.f.adapter.profileBody = {
        ...customerProfileJson(),
        'profilePhoto': 'https://example.com/avatar.jpg',
      };
      await marketEntry(tester, f.f);
      await continueMarket(tester);
      final router = GoRouter.of(tester.element(find.byType(CustomerTopBar)));
      for (final route in ['/home', '/opportunities', '/services', '/wallet']) {
        router.go(route);
        await tester.pumpAndSettle();
        final avatar = find.descendant(
          of: find.byKey(const ValueKey('customer-home-account')),
          matching: find.byType(Image),
        );
        expect(avatar, findsOneWidget, reason: route);
        expect(
          (tester.widget<Image>(avatar).image as NetworkImage).url,
          'https://example.com/avatar.jpg',
        );
      }
      f.f.adapter.profileBody = customerProfileJson();
      final profile = ProviderScope.containerOf(
        tester.element(find.byType(CustomerTopBar)),
      ).read(customerProfileControllerProvider);
      final reload = profile.load();
      await tester.pumpAndSettle();
      await reload;
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('customer-home-account')),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      expect(find.text('J'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

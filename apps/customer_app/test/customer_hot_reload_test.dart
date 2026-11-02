import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/app/customer_config.dart';
import 'package:customer_app/app/customer_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'hot reload keeps bootstrap configuration, router and current route',
    (tester) async {
      var configReads = 0;
      var routerCreations = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRouterProvider.overrideWith((ref) {
              ref.watch(customerConfigProvider);
              routerCreations++;
              final router = GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const Scaffold(body: Text('Start')),
                  ),
                  GoRoute(
                    path: '/booking-review',
                    builder: (_, _) =>
                        const Scaffold(body: Text('Booking review draft')),
                  ),
                ],
              );
              ref.onDispose(router.dispose);
              return router;
            }),
          ],
          child: CustomerBootstrap(
            loadConfig: () {
              configReads++;
              return CustomerConfig(
                apiBaseUrl: 'https://example.invalid/api/v1',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomerApp)),
      );
      final config = container.read(customerConfigProvider);
      final router = container.read(customerRouterProvider);
      router.go('/booking-review');
      await tester.pumpAndSettle();
      expect(find.text('Booking review draft'), findsOneWidget);
      final reload = tester.binding.reassembleApplication();
      await tester.pump();
      await reload;
      await tester.pumpAndSettle();
      expect(container.read(customerConfigProvider), same(config));
      expect(container.read(customerRouterProvider), same(router));
      expect(configReads, 1);
      expect(routerCreations, 1);
      expect(find.text('Booking review draft'), findsOneWidget);
    },
  );
}

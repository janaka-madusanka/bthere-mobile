import 'package:customer_app/app/customer_providers.dart';
import 'package:customer_app/features/booking/presentation/customer_service_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timer accepts offset instants and never guesses market wall time', () {
    expect(
      serviceTimerInstant('2026-11-19T10:15:02.123456+05:30'),
      DateTime.parse('2026-11-19T04:45:02.123456Z'),
    );
    expect(serviceTimerInstant('2026-11-19T10:15:02'), isNull);
    expect(serviceTimerInstant(null), isNull);
  });
  testWidgets(
    'elapsed clock restores actual start, ticks and freezes at provider finish',
    (tester) async {
      var now = DateTime.utc(2026, 11, 20, 10);
      final start = now.subtract(const Duration(hours: 1, minutes: 23));
      Future<void> show(Map<String, dynamic> booking) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [customerClockProvider.overrideWithValue(() => now)],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  child: CustomerServiceTimer(booking: booking),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      final booking = {
        'status': 'IN_PROGRESS',
        'actualStartedAt': start.toIso8601String(),
      };
      await show(booking);
      expect(find.text('01:23:00'), findsOneWidget);
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('01:23:02'), findsOneWidget);
      final finished = {
        ...booking,
        'status': 'AWAITING_COMPLETION_CONFIRMATION',
        'actualFinishedAt': now.toIso8601String(),
      };
      await show(finished);
      now = now.add(const Duration(hours: 1));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('01:23:02'), findsOneWidget);
      expect(find.text('Service duration'), findsOneWidget);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await show({
        ...finished,
        'status': 'COMPLETED',
        'completionConfirmedAt': now.toIso8601String(),
      });
      expect(find.text('01:23:02'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('resume recalculates elapsed time after background pause', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 20, 10);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [customerClockProvider.overrideWithValue(() => now)],
        child: MaterialApp(
          home: Scaffold(
            body: CustomerServiceTimer(
              booking: const {
                'status': 'IN_PROGRESS',
                'actualStartedAt': '2026-11-20T09:00:00Z',
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('01:00:00'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    now = now.add(const Duration(minutes: 30));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('01:00:00'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('01:30:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'missing, future, invalid and unstarted data never show a guessed timer',
    (tester) async {
      final now = DateTime.utc(2026, 11, 20, 10);
      for (final booking in <Map<String, dynamic>>[
        {'status': 'IN_PROGRESS', 'startDatetime': '2026-11-20T08:00:00'},
        {
          'status': 'IN_PROGRESS',
          'actualStartedAt': now
              .add(const Duration(minutes: 1))
              .toIso8601String(),
        },
        {'status': 'COMPLETED', 'actualStartedAt': '2026-11-20T08:00:00Z'},
        {'status': 'CONFIRMED', 'actualStartedAt': '2026-11-20T08:00:00Z'},
        {
          'status': 'IN_PROGRESS',
          'actualStartedAt': '2026-11-20T08:00:00Z',
          'actualFinishedAt': 'bad',
        },
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [customerClockProvider.overrideWithValue(() => now)],
            child: MaterialApp(
              home: Scaffold(body: CustomerServiceTimer(booking: booking)),
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('booking-service-timer')),
          findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}

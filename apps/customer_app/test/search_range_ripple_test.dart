import 'package:customer_app/app/widgets/search_range_ripple.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SearchRangeRipplePainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('search-range-ripple-paint')),
            )
            .painter!
        as SearchRangeRipplePainter;

Future<void> render(
  WidgetTester tester, {
  String token = 'initial',
  bool ready = true,
  bool paused = false,
  bool reduced = false,
  bool repeat = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: SizedBox(
        width: 300,
        height: 300,
        child: SearchRangeRipple(
          repeat: repeat,
          trigger: token,
          paused: paused,
          center: ready ? const Offset(150, 150) : null,
          radius: ready ? 100 : null,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'repeats after an idle gap and pauses for gestures and background',
    (tester) async {
      await render(tester, repeat: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(painter(tester).animation.value, closeTo(.25, .01));
      await tester.pump(const Duration(milliseconds: 2120));
      expect(painter(tester).animation.value, 1);
      await tester.pump();
      expect(
        (painter(tester).animation as AnimationController).isAnimating,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 1300));
      expect(painter(tester).animation.value, 1);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));
      expect(painter(tester).animation.value, closeTo(.25, .01));
      await render(tester, repeat: true, paused: true);
      await tester.pump(const Duration(seconds: 6));
      expect(painter(tester).animation.value, 0);
      await render(tester, repeat: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(painter(tester).animation.value, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 6));
      expect(painter(tester).animation.value, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(painter(tester).animation.value, greaterThan(0));
      await render(tester, repeat: true, reduced: true);
      await tester.pump(const Duration(seconds: 6));
      expect(painter(tester).animation.value, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('covered routes stop repeating and resume when the map returns', (
    tester,
  ) async {
    await render(tester, repeat: true);
    await tester.pump(const Duration(milliseconds: 700));
    final navigator = Navigator.of(
      tester.element(find.byType(SearchRangeRipple)),
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    final hiddenPaint = tester.widget<CustomPaint>(
      find.byKey(
        const ValueKey('search-range-ripple-paint'),
        skipOffstage: false,
      ),
    );
    expect(
      (hiddenPaint.painter! as SearchRangeRipplePainter).animation.value,
      0,
    );
    navigator.pop();
    await tester.pumpAndSettle();
    expect(painter(tester).animation.value, 1);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 700));
    expect(painter(tester).animation.value, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'queues latest filter until geometry is ready, then finishes once',
    (tester) async {
      await render(tester);
      expect(painter(tester).animation.value, 0);
      await render(tester, token: 'location', ready: false, paused: true);
      await render(tester, token: 'location-tamil', ready: false, paused: true);
      await tester.pump(const Duration(seconds: 2));
      expect(painter(tester).animation.value, 0);
      await render(tester, token: 'location-tamil');
      await tester.pump(const Duration(milliseconds: 700));
      expect(painter(tester).animation.value, closeTo(.25, .01));
      await tester.pumpAndSettle();
      expect(painter(tester).animation.value, 1);
      await render(tester, token: 'location-tamil');
      expect(painter(tester).animation.value, 1);
    },
  );

  testWidgets(
    'reduced motion drops pending playback instead of replaying later',
    (tester) async {
      await render(tester);
      await render(tester, token: 'date', ready: false, paused: true);
      await render(tester, token: 'date', reduced: true);
      await render(tester, token: 'date');
      await tester.pumpAndSettle();
      expect(painter(tester).animation.value, 0);
      await render(tester, token: 'time');
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter(tester).animation.value, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}

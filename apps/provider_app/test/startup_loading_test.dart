import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/startup/presentation/startup_screen.dart';

void main() {
  testWidgets('startup stays light on a dark device and fits a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: StartupLoadingPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Getting things ready for you…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });
  testWidgets('startup error preserves the working retry action', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupLoadingPage(
          message: 'Unable to check your account',
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Retry account setup'));
    expect(retries, 1);
    await tester.pumpWidget(const SizedBox());
  });
}

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final compact in [false, true]) {
    testWidgets('loading state is accessible and scales; compact=$compact', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: BThereTheme.authentication(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
              child: Center(
                child: SizedBox(
                  width: 240,
                  child: BThereLoadingState(
                    label: 'Loading service requirements',
                    compact: compact,
                    placeholder: compact
                        ? null
                        : const BThereSkeleton(height: 40),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Loading service requirements'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byType(BThereLoadingState)),
        matchesSemantics(
          label: 'Loading service requirements',
          isLiveRegion: true,
        ),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}

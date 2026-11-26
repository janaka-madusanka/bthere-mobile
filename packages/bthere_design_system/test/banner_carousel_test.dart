import 'dart:async';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'auto advances, pauses in background and fills image bounds without elevation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BthereBannerCarousel(
              load: () async => const [
                BannerSlide(
                  id: 1,
                  title: 'First',
                  imageUrl: 'https://example.com/1.png',
                ),
                BannerSlide(
                  id: 2,
                  title: 'Second',
                  imageUrl: 'https://example.com/2.png',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(pages.page, 0);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(pages.page, 1);
      final image = find.byType(Image).first;
      expect(tester.getSize(image), tester.getSize(find.byType(AspectRatio)));
      final material = tester.widget<Material>(
        find.ancestor(of: image, matching: find.byType(Material)).first,
      );
      expect(material.elevation, 0);
      expect(material.color, Colors.transparent);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 6));
      expect(pages.page, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(pages.page, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'loading occupies 2:1 space; empty and failed optional content hide',
    (tester) async {
      final gate = Completer<List<BannerSlide>>();
      await tester.pumpWidget(
        MaterialApp(home: BthereBannerCarousel(load: () => gate.future)),
      );
      expect(find.bySemanticsLabel('Loading banner'), findsOneWidget);
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio).first).aspectRatio,
        2,
      );
      gate.complete([]);
      await tester.pump();
      expect(find.byType(AspectRatio), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: BthereBannerCarousel(
            key: const ValueKey('error'),
            load: () async => throw Exception('offline'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AspectRatio), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

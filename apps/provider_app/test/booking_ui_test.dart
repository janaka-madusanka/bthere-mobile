import 'dart:io';
import 'dart:ui' as ui;

import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/features/bookings/application/booking_controller.dart';
import 'package:provider_app/features/bookings/domain/booking_models.dart';
import 'package:provider_app/features/bookings/presentation/booking_detail_screen.dart';
import 'package:provider_app/features/bookings/presentation/opportunities_screen.dart';
import 'package:provider_app/features/messages/presentation/messages_screen.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';

import 'booking_api_test.dart' show offerJson;
import 'support/fake_service_repository.dart';
import 'support/fake_session_storage.dart';

class PreviewBookings extends BookingController {
  @override
  Future<BookingState> build() async =>
      BookingState(offers: [BookingOffer.fromJson(offerJson())]);
}

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('booking screens and incoming request fit width $width', (
      tester,
    ) async {
      tester.view.physicalSize = ui.Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final services = FakeServiceRepository()
        ..catalog = const Success([
          ProviderServiceType(id: 3, name: 'Caregiving', status: 'ACTIVE'),
        ]);
      var now = testNow;
      final container = ProviderContainer(
        overrides: [
          bookingControllerProvider.overrideWith(PreviewBookings.new),
          providerServiceRepositoryProvider.overrideWithValue(services),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      const key = ValueKey('booking-preview');
      Future<void> mount(Widget screen) async {
        await tester.runAsync(() async {
          for (final font in [
            ('HomeLato', 'Lato-Regular.ttf'),
            ('HomeLato', 'Lato-Bold.ttf'),
            ('HomeLato', 'Lato-Black.ttf'),
          ]) {
            await (FontLoader(
              font.$1,
            )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
          }
          final sdk = Platform.environment['FLUTTER_ROOT'];
          if (sdk != null) {
            await (FontLoader('MaterialIcons')..addFont(
                  File(
                    '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
                  ).readAsBytes().then(ByteData.sublistView),
                ))
                .load();
          }
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: RepaintBoundary(
                key: key,
                child: Scaffold(body: screen),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        if (width != 430) return;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        await tester.runAsync(() async {
          final picture = await boundary.toImage();
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/booking-previews/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          picture.dispose();
        });
      }

      await mount(const OpportunitiesScreen());
      expect(find.text("You'll earn LKR 850.00"), findsOneWidget);
      expect(find.textContaining('1,000'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture('opportunities');
      await tester.tap(find.text('New (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsOneWidget);
      await mount(const MessagesScreen());
      expect(find.text('No conversations yet'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Kamala');
      await tester.pump();
      expect(find.text('No conversations found'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('messages');
      await mount(
        IncomingBookingDialog(offer: BookingOffer.fromJson(offerJson())),
      );
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('59s remaining'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('incoming');
      await tester.pumpWidget(const SizedBox());
    });
  }
}

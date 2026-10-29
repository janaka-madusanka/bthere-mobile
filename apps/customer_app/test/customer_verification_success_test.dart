import 'package:customer_app/features/auth/application/customer_auth_controller.dart';
import 'package:customer_app/features/auth/presentation/customer_verification_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'customer_auth_test.dart' show Fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('supplied local animation parses without remote image assets', () async {
    final bytes = await rootBundle.load(
      'assets/animations/verification_success.json',
    );
    final composition = await LottieComposition.fromBytes(
      bytes.buffer.asUint8List(),
    );
    expect(composition.duration, const Duration(milliseconds: 2400));
    expect(composition.bounds.width, 200);
    expect(composition.bounds.height, 200);
    expect(composition.images, isEmpty);
  });
  for (final phone in [false, true]) {
    test(
      '${phone ? 'phone' : 'email'} success is transient and requires secure authenticated user',
      () async {
        final f = Fixture();
        addTearDown(f.dispose);
        await f.controller.restore();
        if (phone) {
          await f.controller.requestPhoneOtp('+94771234567');
          await f.controller.verifyPhoneOtp('001234');
        } else {
          await f.controller.register('test@example.com', 'password-123');
          await f.controller.verify('001234');
        }
        expect(f.controller.stage, CustomerAuthStage.authenticated);
        expect(f.storage.value, isNotNull);
        expect(
          f.controller.verificationSuccess,
          phone
              ? CustomerVerificationChannel.phone
              : CustomerVerificationChannel.email,
        );
        f.controller.continueAfterVerification();
        expect(f.controller.verificationSuccess, isNull);
        expect(f.storage.value, isNotNull);
        f.controller.continueAfterVerification();
        await f.controller.restore();
        expect(f.controller.verificationSuccess, isNull);
      },
    );
    test(
      '${phone ? 'phone' : 'email'} failed persistence never signals success',
      () async {
        final f = Fixture();
        addTearDown(f.dispose);
        await f.controller.restore();
        f.storage.failWrite = true;
        if (phone) {
          await f.controller.requestPhoneOtp('+94771234567');
          await f.controller.verifyPhoneOtp('001234');
        } else {
          await f.controller.register('test@example.com', 'password-123');
          await f.controller.verify('001234');
        }
        expect(f.controller.verificationSuccess, isNull);
        expect(f.controller.stage, isNot(CustomerAuthStage.authenticated));
      },
    );
  }
  test(
    'logout dismisses success and preserves normal signed-out routing state',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.controller.requestPhoneOtp('+94771234567');
      await f.controller.verifyPhoneOtp('001234');
      await f.controller.logout();
      expect(f.controller.verificationSuccess, isNull);
      expect(f.controller.stage, CustomerAuthStage.signedOut);
    },
  );
  testWidgets(
    'success respects reduced motion and keeps Continue reachable with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      var continued = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerVerificationSuccessPage(
            phone: false,
            onContinue: () => continued++,
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final animation = tester.widget<Lottie>(find.byType(Lottie));
      expect(animation.controller?.value, 1);
      expect(animation.controller?.isAnimating, isFalse);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-verification-success-continue')),
      );
      await tester.tap(
        find.byKey(const ValueKey('customer-verification-success-continue')),
      );
      expect(continued, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

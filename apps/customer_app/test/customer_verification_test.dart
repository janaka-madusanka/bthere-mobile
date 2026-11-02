import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:customer_app/features/auth/presentation/customer_verification_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Public Sans',
    )..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'))).load();
  });
  for (final phone in [false, true]) {
    for (final size in [const Size(360, 800), const Size(430, 932)]) {
      testWidgets('${phone ? 'phone' : 'email'} verification layout at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final otp = TextEditingController();
        addTearDown(otp.dispose);
        final form = GlobalKey<FormState>();
        var submitted = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: CustomerVerificationPage(
              formKey: form,
              otp: otp,
              phone: phone,
              destination: phone ? '+94771234567' : 'customer@example.com',
              remaining: 30,
              busy: false,
              error: null,
              onSubmit: () {
                if (form.currentState!.validate()) submitted++;
              },
              onResend: () {},
              onChangeDestination: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(phone ? 'Verify your phone' : 'Verify your email'),
          findsOneWidget,
        );
        expect(find.text('Resend code (00:30)'), findsOneWidget);
        for (var i = 0; i < 6; i++) {
          expect(find.byKey(ValueKey('customer-otp-slot-$i')), findsOneWidget);
        }
        expect(
          find.text(phone ? 'Can’t find the SMS?' : 'Can’t find the email?'),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('customer-auth-submit')),
        );
        await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Enter the six-digit code.'), findsOneWidget);
        expect(submitted, 0);
        await tester.enterText(
          find.byKey(const ValueKey('customer-otp')),
          '001234',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('customer-auth-submit')),
        );
        await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
        await tester.pumpAndSettle();
        expect(submitted, 1);
        expect(otp.text, '001234');
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('resend and change destination are disabled while busy', (
    tester,
  ) async {
    final otp = TextEditingController();
    addTearDown(otp.dispose);
    var resend = 0, change = 0;
    Future<void> pump(bool busy, int remaining) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerVerificationPage(
            formKey: GlobalKey<FormState>(),
            otp: otp,
            phone: true,
            destination: '+94771234567',
            remaining: remaining,
            busy: busy,
            error: null,
            onSubmit: () {},
            onResend: () => resend++,
            onChangeDestination: () => change++,
          ),
        ),
      );
      await tester.pump();
    }

    await pump(false, 30);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('customer-otp-resend')))
          .onPressed,
      isNull,
    );
    await pump(true, 0);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('customer-otp-resend')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('customer-otp-change-destination')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<BTherePrimaryButton>(
            find.byKey(const ValueKey('customer-auth-submit')),
          )
          .loading,
      isTrue,
    );
    await pump(false, 0);
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-otp-resend')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-otp-resend')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-otp-change-destination')),
    );
    await tester.tap(
      find.byKey(const ValueKey('customer-otp-change-destination')),
    );
    expect(resend, 1);
    expect(change, 1);
  });
  testWidgets('large text and keyboard keep verification actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final otp = TextEditingController();
    addTearDown(otp.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerVerificationPage(
          formKey: GlobalKey<FormState>(),
          otp: otp,
          phone: false,
          destination: 'long-customer-address@example.com',
          remaining: 0,
          busy: false,
          error: 'Your code is invalid or expired.',
          onSubmit: () {},
          onResend: () {},
          onChangeDestination: () {},
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-auth-submit')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verify and continue').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

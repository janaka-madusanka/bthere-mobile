import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bthere_design_system/bthere_design_system.dart';

void main() {
  test('authentication theme is bright and flat without replacing global feature themes', () {
    final auth = BThereTheme.authentication();
    expect(auth.brightness, Brightness.light);
    expect(auth.scaffoldBackgroundColor, BThereColors.background);
    expect(auth.filledButtonTheme.style!.elevation!.resolve({}), 0);
    expect(
      auth.filledButtonTheme.style!.elevation!.resolve({WidgetState.pressed}),
      0,
    );
    expect(BThereTheme.dark().colorScheme.primary, BThereDarkColors.primary);
    expect(BThereTheme.light().colorScheme.primary, BThereColors.primary);
  });
  test('auth action and large emphasis colors maintain readable contrast', () {
    double ratio(Color a, Color b) {
      final first = a.computeLuminance(), second = b.computeLuminance();
      return first > second
          ? (first + .05) / (second + .05)
          : (second + .05) / (first + .05);
    }

    expect(
      ratio(BThereColors.primaryAction, BThereColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      ratio(BThereColors.primaryEmphasis, BThereColors.background),
      greaterThanOrEqualTo(3),
    );
  });
  testWidgets(
    'above-field label remains visible and accessible while editing',
    (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      await tester.pumpWidget(
        host(
          BThereTextField(
            label: 'Email address',
            hint: 'you@example.com',
            labelPlacement: BThereFieldLabelPlacement.above,
            helperText: 'Use your email.',
            controller: controller,
            prefix: const Icon(Icons.mail_outline),
          ),
        ),
      );
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Use your email.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Email address')).dy,
        lessThan(tester.getTopLeft(find.byType(TextFormField)).dy),
      );
      await tester.enterText(
        find.byType(TextFormField),
        'provider@example.com',
      );
      expect(controller.text, 'provider@example.com');
      expect(find.text('Email address'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(EditableText)).getSemanticsData().label,
        contains('Email address'),
      );
      handle.dispose();
      controller.dispose();
    },
  );
  testWidgets(
    'trailing button icon preserves label and loading/disabled interaction',
    (tester) async {
      var taps = 0;
      for (final loading in [false, true]) {
        await tester.pumpWidget(
          host(
            BThereButton(
              label: 'Continue',
              onPressed: () => taps++,
              trailingIcon: const Icon(Icons.arrow_forward),
              loading: loading,
            ),
          ),
        );
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pump();
        expect(taps, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          loading ? isNull : isNotNull,
        );
      }
    },
  );
  testWidgets(
    'above labels and centered input support large text at narrow width',
    (tester) async {
      await tester.pumpWidget(
        host(
          const BThereTextField(
            label: 'Verification code',
            labelPlacement: BThereFieldLabelPlacement.above,
            textAlign: TextAlign.center,
            textStyle: BThereTypography.h3,
            helperText: 'Enter the code sent to your email.',
          ),
          scale: 2.5,
        ),
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).textAlign,
        TextAlign.center,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('caller can disable suggestions when secure text is revealed', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const BThereTextField(
          obscureText: false,
          autocorrect: false,
          enableSuggestions: false,
        ),
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.obscureText, isFalse);
    expect(editable.autocorrect, isFalse);
    expect(editable.enableSuggestions, isFalse);
  });
  test('approved primary, spacing rhythm and control/surface radii', () {
    expect(BThereColors.primary, const Color(0xFF0F666B));
    expect(
      [
        BThereSpacing.xxs,
        BThereSpacing.xs,
        BThereSpacing.sm,
        BThereSpacing.md,
        BThereSpacing.lg,
        BThereSpacing.xl,
        BThereSpacing.xxl,
        BThereSpacing.xxxl,
      ],
      [4, 8, 12, 16, 24, 32, 40, 48],
    );
    expect(BThereRadius.control, 16);
    expect(BThereRadius.surface, 24);
  });
  for (final dark in [false, true]) {
    test('${dark ? 'dark' : 'light'} Material 3 theme has readable roles', () {
      final theme = dark ? BThereTheme.dark() : BThereTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
      expect(theme.textTheme.headlineLarge!.fontSize, 28);
      expect(
        theme.textTheme.bodyMedium!.fontFamily,
        BThereTypography.fontFamily,
      );
      final colors = theme.colorScheme;
      for (final pair in [
        (colors.onSurface, colors.surface),
        (colors.onSurfaceVariant, theme.scaffoldBackgroundColor),
        (colors.onPrimary, colors.primary),
        (colors.onSecondary, colors.secondary),
        (colors.error, colors.surface),
      ]) {
        final a = pair.$1.computeLuminance();
        final b = pair.$2.computeLuminance();
        final contrast = a > b
            ? (a + 0.05) / (b + 0.05)
            : (b + 0.05) / (a + 0.05);
        expect(
          contrast,
          greaterThanOrEqualTo(4.5),
          reason: '${pair.$1} on ${pair.$2}',
        );
      }
    });
  }
  testWidgets('button label and tap callback work with a mobile touch target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(BThereButton(label: 'Continue', onPressed: () => taps++)),
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
  });
  for (final loading in [false, true]) {
    testWidgets(
      '${loading ? 'loading' : 'disabled'} button blocks repeat taps and retains label',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          host(
            BThereButton(
              label: 'Continue',
              onPressed: () => taps++,
              enabled: loading,
              loading: loading,
            ),
          ),
        );
        await tester.tap(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        expect(taps, 0);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          find.byType(BThereLoadingIndicator),
          loading ? findsOneWidget : findsNothing,
        );
        expect(find.text('Continue'), findsOneWidget);
      },
    );
  }
  testWidgets('outlined button supports leading icon and full width', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        BThereButton(
          label: 'Continue',
          onPressed: () {},
          variant: BThereButtonVariant.outlined,
          leadingIcon: const Icon(Icons.arrow_forward),
          fullWidth: true,
        ),
      ),
    );
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(tester.getSize(find.byType(OutlinedButton)).width, 320);
  });
  testWidgets('button wraps at narrow width with large text', (tester) async {
    await tester.pumpWidget(
      host(
        BThereButton(
          label: 'Continue with this selection',
          onPressed: () {},
          leadingIcon: const Icon(Icons.arrow_forward),
          fullWidth: true,
        ),
        scale: 2.5,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThan(56));
  });
  testWidgets('field renders label and hint then accepts controller input', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        BThereTextField(
          label: 'Contact',
          hint: 'Enter a value',
          controller: controller,
        ),
      ),
    );
    expect(find.text('Contact'), findsOneWidget);
    expect(find.text('Enter a value'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'sample');
    expect(controller.text, 'sample');
  });
  testWidgets('caller controls obscure mode and input metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const BThereTextField(
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          autofillHints: [AutofillHints.password],
        ),
      ),
    );
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.obscureText, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.textInputAction, TextInputAction.done);
    expect(field.autofillHints, [AutofillHints.password]);
  });
  testWidgets('disabled field does not focus or accept user input', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'original');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(BThereTextField(controller: controller, enabled: false)),
    );
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    expect(controller.text, 'original');
  });
  testWidgets('field exposes error text and prefix/suffix widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const BThereTextField(
          errorText: 'Try again',
          prefix: Icon(Icons.search),
          suffix: Icon(Icons.clear),
        ),
      ),
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);
  });
  testWidgets('field delegates validation to the caller', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      host(
        Form(
          key: key,
          child: BThereTextField(
            validator: (value) => value == 'ok' ? null : 'Caller validation',
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Caller validation'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'ok');
    expect(key.currentState!.validate(), isTrue);
  });
  testWidgets('generic state view renders optional copy and caller action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        BThereStateView(
          title: 'Nothing here',
          message: 'Try later',
          action: BThereButton(label: 'Retry', onPressed: () => taps++),
        ),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Try later'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(taps, 1);
  });
  testWidgets('loading indicator exposes caller semantics and theme color', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const BThereLoadingIndicator(semanticsLabel: 'Loading')),
    );
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .color,
      isNull,
    );
    handle.dispose();
  });
}

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: BThereTheme.light(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    ),
  ),
);

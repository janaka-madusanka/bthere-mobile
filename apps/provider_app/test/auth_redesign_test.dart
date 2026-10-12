import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/auth/widgets/auth_primary_button.dart';

import 'email_auth_screen_test.dart' as flow;
import 'support/fake_auth_repository.dart';
import 'support/fake_session_storage.dart';

void main() {
  for (final label in ['Sign in', 'Create Account']) {
    for (final scale in [1.0, 2.5]) {
      testWidgets('$label keeps loading dimensions at text scale $scale', (
        tester,
      ) async {
        Widget page(bool loading) => MaterialApp(
          theme: BThereTheme.authentication(),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(
                child: SizedBox(
                  width: 288,
                  child: AuthPrimaryButton(
                    label: label,
                    loading: loading,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(page(false));
        final size = tester.getSize(find.byType(FilledButton));
        await tester.pumpWidget(page(true));
        await tester.pump();
        expect(tester.getSize(find.byType(FilledButton)), size);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'legal consent is local and unsupported actions remain disabled',
    (tester) async {
      final repo = FakeAuthRepository();
      await flow.pumpAuth(tester, repo, FakeSessionStorage());
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('auth-forgot-password')),
            )
            .onPressed,
        isNull,
      );
      for (final registering in [false, true]) {
        if (registering) await flow.openRegistration(tester);
        for (final key in ['auth-social-google', 'auth-social-apple']) {
          final button = tester.widget<BThereButton>(find.byKey(ValueKey(key)));
          expect(button.enabled, isFalse);
          expect(button.onPressed, isNull);
        }
        for (final key in ['auth-privacy', 'auth-terms']) {
          expect(
            tester.widget<TextButton>(find.byKey(ValueKey(key))).onPressed,
            isNull,
          );
        }
      }
      final checkbox = find.byKey(const ValueKey('auth-legal-checkbox'));
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      expect(repo.logins + repo.registrations + repo.googleAuthentications, 0);
    },
  );
}

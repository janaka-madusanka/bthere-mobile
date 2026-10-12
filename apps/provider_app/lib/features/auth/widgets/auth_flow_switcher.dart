import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';

/// Route-based tabs keep registration and sign-in credential state separate.
class AuthFlowSwitcher extends StatelessWidget {
  const AuthFlowSwitcher({
    super.key,
    required this.signingIn,
    this.busy = false,
  });
  final bool signingIn;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget tab(String label, bool selected, String route, Key key) => Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          key: key,
          onPressed: busy
              ? null
              : () {
                  if (!selected) context.go(route);
                },
          style: TextButton.styleFrom(
            backgroundColor: selected ? colors.primary : null,
            foregroundColor: selected
                ? colors.onPrimary
                : colors.onSurfaceVariant,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BThereRadius.segmented),
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(BThereRadius.segmented),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            tab(
              'Sign in',
              signingIn,
              AppRoutes.auth,
              const ValueKey('auth-sign-in-tab'),
            ),
            tab(
              'Create account',
              !signingIn,
              AppRoutes.emailRegistration,
              const ValueKey('auth-create-account-tab'),
            ),
          ],
        ),
      ),
    );
  }
}

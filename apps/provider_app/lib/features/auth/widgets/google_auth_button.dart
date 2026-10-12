import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

import 'auth_brand_image.dart';

/// Provider's Google action retains shared sizing, radius and busy semantics.
class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({
    super.key,
    required this.onPressed,
    required this.loading,
  });
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.outlinedButtonTheme.style ?? const ButtonStyle();
    final colors = theme.colorScheme;
    return OutlinedButtonTheme(
      data: OutlinedButtonThemeData(
        style: base.copyWith(
          backgroundColor: WidgetStatePropertyAll(colors.surface),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? base.foregroundColor?.resolve(states)
                : colors.onSurface,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? base.side?.resolve(states)
                : BorderSide(color: colors.outline),
          ),
        ),
      ),
      child: BThereButton(
        label: 'Continue with Google',
        fullWidth: true,
        variant: BThereButtonVariant.outlined,
        leadingIcon: const AuthBrandImage(
          asset: AuthBrandAsset.google,
          width: 20,
        ),
        loading: loading,
        onPressed: onPressed,
      ),
    );
  }
}

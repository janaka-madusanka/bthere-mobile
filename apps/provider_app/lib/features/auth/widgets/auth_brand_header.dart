import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

import 'auth_brand_image.dart';

/// Supplied B there artwork shared by all email authentication screens.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.accent,
    this.marketing = false,
  });
  const AuthBrandHeader.marketing({super.key})
    : title = '',
      subtitle = '',
      accent = null,
      marketing = true;
  final String title;
  final String subtitle;
  final String? accent;
  final bool marketing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AuthBrandImage(
          asset: AuthBrandAsset.carePromise,
          semanticLabel: 'B there Provider — Care Promise',
        ),
        const SizedBox(height: BThereSpacing.lg),
        Semantics(
          header: true,
          child: marketing
              ? Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Turn your skills into\n'),
                      TextSpan(
                        text: 'meaningful care.',
                        style: TextStyle(color: BThereColors.primaryEmphasis),
                      ),
                    ],
                  ),
                  key: const ValueKey('auth-marketing-headline'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge,
                )
              : Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    letterSpacing: -0.5,
                  ),
                ),
        ),
        if (accent != null)
          Text(
            accent!,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: -0.5,
            ),
          ),
        const SizedBox(height: BThereSpacing.sm),
        Text(
          marketing
              ? 'Join Bthere and make a real difference\nin people’s lives.'
              : subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

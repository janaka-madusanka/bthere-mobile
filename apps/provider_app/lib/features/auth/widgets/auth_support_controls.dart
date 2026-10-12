import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import 'auth_brand_image.dart';

/// Visual-only until social authentication is explicitly connected.
class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(child: Divider()),
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BThereSpacing.md),
              child: Text(
                'or continue with',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
      const SizedBox(height: BThereSpacing.md),
      for (final provider in [AuthBrandAsset.google, AuthBrandAsset.apple]) ...[
        Tooltip(
          message:
              '${provider == AuthBrandAsset.google ? 'Google' : 'Apple'} sign-in is not available yet.',
          child: BThereButton(
            key: ValueKey('auth-social-${provider.name}'),
            label:
                'Continue with ${provider == AuthBrandAsset.google ? 'Google' : 'Apple'}',
            leadingIcon: AuthBrandImage(asset: provider, width: 20),
            variant: BThereButtonVariant.outlined,
            fullWidth: true,
            enabled: false,
            onPressed: null,
          ),
        ),
        const SizedBox(height: BThereSpacing.sm),
      ],
      Text(
        'Social sign-in is not available yet.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class AuthAgreementRow extends StatelessWidget {
  const AuthAgreementRow({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool?>? onChanged;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Checkbox(
        key: const ValueKey('auth-legal-checkbox'),
        value: value,
        onChanged: onChanged,
        semanticLabel: 'I agree to the Terms of Service and Privacy Policy',
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BThereSpacing.sm),
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class AuthExistingAccountLink extends StatelessWidget {
  const AuthExistingAccountLink({super.key, required this.busy});
  final bool busy;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        'Already have an account?',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      TextButton(
        key: const ValueKey('auth-existing-account'),
        onPressed: busy ? null : () => context.go(AppRoutes.auth),
        child: const Text('Sign in'),
      ),
    ],
  );
}

/// No invented destinations: these controls are visibly disabled.
class AuthFooterLinks extends StatelessWidget {
  const AuthFooterLinks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton(
        key: const ValueKey('auth-privacy'),
        onPressed: null,
        child: const Text('Privacy'),
      ),
      const ExcludeSemantics(child: Text('|')),
      TextButton(
        key: const ValueKey('auth-terms'),
        onPressed: null,
        child: const Text('Terms'),
      ),
    ],
  );
}

import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

import 'customer_brand_image.dart';

/// Same visual foundation as Provider auth, with Customer-owned state/copy.
class CustomerAuthPage extends StatelessWidget {
  const CustomerAuthPage({
    super.key,
    required this.child,
    required this.registering,
    required this.verifying,
    required this.busy,
    required this.onModeChanged,
  });
  final Widget child;
  final bool registering, verifying, busy;
  final ValueChanged<bool> onModeChanged;

  ThemeData _theme() {
    final base = CustomerTheme.authentication();
    if (registering || verifying) return base;
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.all(12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _theme(),
    child: Builder(
      builder: (context) => Scaffold(
        body: BThereBrandedBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final horizontal = bounds.maxWidth < 360
                    ? BThereSpacing.md
                    : bounds.maxWidth >= 400
                    ? BThereSpacing.xxl
                    : BThereSpacing.lg;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontal,
                    vertical: registering || verifying ? BThereSpacing.lg : 12,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 440,
                        minHeight:
                            (bounds.maxHeight -
                                    (registering || verifying
                                        ? BThereSpacing.lg * 2
                                        : 24))
                                .clamp(0, double.infinity),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!registering && !verifying)
                                SizedBox(
                                  height: ((bounds.maxHeight - 760) * .2).clamp(
                                    0,
                                    40,
                                  ),
                                ),
                              Center(
                                child: BThereBrandImage(
                                  asset: BThereBrandAsset.carePromise,
                                  width: registering || verifying ? 155 : 112,
                                  semanticLabel:
                                      'B there Customer — Care Promise',
                                ),
                              ),
                              if (!registering && !verifying) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Be there when care is matter',
                                  key: const ValueKey('customer-login-slogan'),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: CustomerColors.action,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 24,
                                        height: 1.25,
                                      ),
                                ),
                                const SizedBox(height: 16),
                              ] else ...[
                                const SizedBox(height: BThereSpacing.lg),
                                Semantics(
                                  header: true,
                                  child: Text.rich(
                                    const TextSpan(
                                      children: [
                                        TextSpan(text: 'Care you can trust,\n'),
                                        TextSpan(
                                          text: 'when it matters.',
                                          style: TextStyle(
                                            color: CustomerColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    key: const ValueKey(
                                      'customer-auth-headline',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge,
                                  ),
                                ),
                                const SizedBox(height: BThereSpacing.sm),
                                Text(
                                  'Find the right care for you\nand the people you love.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: BThereSpacing.lg),
                              ],
                              if (!verifying) ...[
                                _FlowTabs(
                                  registering: registering,
                                  busy: busy,
                                  onChanged: onModeChanged,
                                ),
                                SizedBox(
                                  height: registering || verifying
                                      ? BThereSpacing.lg
                                      : 12,
                                ),
                              ],
                              child,
                              if (!verifying) ...[
                                SizedBox(
                                  height: registering ? BThereSpacing.lg : 8,
                                ),
                                _SocialButtons(compact: !registering),
                                SizedBox(
                                  height: registering ? BThereSpacing.lg : 8,
                                ),
                              ],
                            ],
                          ),
                          if (!verifying)
                            const Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: null,
                                  child: Text('Privacy'),
                                ),
                                ExcludeSemantics(child: Text('|')),
                                TextButton(
                                  onPressed: null,
                                  child: Text('Terms'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _FlowTabs extends StatelessWidget {
  const _FlowTabs({
    required this.registering,
    required this.busy,
    required this.onChanged,
  });
  final bool registering, busy;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(BThereRadius.segmented),
      ),
      child: Row(
        children: [
          for (final mode in [false, true])
            Expanded(
              child: Semantics(
                selected: mode == registering,
                child: TextButton(
                  key: ValueKey(
                    mode ? 'customer-register-tab' : 'customer-login-tab',
                  ),
                  onPressed: busy
                      ? null
                      : () {
                          if (mode != registering) onChanged(mode);
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: mode == registering
                        ? colors.primary
                        : null,
                    foregroundColor: mode == registering
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        BThereRadius.segmented,
                      ),
                    ),
                  ),
                  child: Text(
                    mode ? 'Create account' : 'Sign in',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialButtons extends StatelessWidget {
  const _SocialButtons({this.compact = false});
  final bool compact;
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
      SizedBox(height: compact ? 8 : BThereSpacing.md),
      for (final asset in [
        BThereBrandAsset.google,
        BThereBrandAsset.apple,
      ]) ...[
        Tooltip(
          message:
              '${asset == BThereBrandAsset.google ? 'Google' : 'Apple'} sign-in is not available yet.',
          child: BThereButton(
            label:
                'Continue with ${asset == BThereBrandAsset.google ? 'Google' : 'Apple'}',
            key: ValueKey('customer-social-${asset.name}'),
            leadingIcon: BThereBrandImage(asset: asset, width: 20),
            variant: BThereButtonVariant.outlined,
            fullWidth: true,
            enabled: false,
            onPressed: null,
          ),
        ),
        SizedBox(height: compact ? 8 : BThereSpacing.sm),
      ],
      if (!compact)
        Text(
          'Social sign-in is not available yet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ],
  );
}

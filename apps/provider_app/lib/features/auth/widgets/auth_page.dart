import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import 'auth_background.dart';
import 'auth_back_button.dart';
import 'auth_brand_header.dart';
import 'auth_flow_switcher.dart';
import 'auth_support_controls.dart';

/// One responsive foundation for email forms; OTP keeps its existing shell.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.child,
    this.backRoute,
    this.busy = false,
    this.centerContent = false,
    this.signingIn,
  });
  final Widget child;
  final String? backRoute;
  final bool busy, centerContent;
  final bool? signingIn;
  static const maxContentWidth = 440.0;

  @override
  Widget build(BuildContext context) {
    final marketing = signingIn != null;
    return Theme(
      data: marketing ? BThereTheme.authentication() : Theme.of(context),
      child: Builder(
        builder: (context) => PopScope(
          canPop: !busy,
          child: Scaffold(
            body: AuthBackground(
              marketing: marketing,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final horizontal = bounds.maxWidth < 360
                        ? BThereSpacing.md
                        : marketing && bounds.maxWidth >= 400
                        ? BThereSpacing.xxl
                        : BThereSpacing.lg;
                    final vertical = BThereSpacing.lg;
                    final minimumHeight = (bounds.maxHeight - vertical * 2)
                        .clamp(0.0, double.infinity);
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontal,
                        vertical: vertical,
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Align(
                        alignment: centerContent
                            ? Alignment.center
                            : Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                            minHeight: minimumHeight,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (marketing) ...[
                                    const AuthBrandHeader.marketing(),
                                    const SizedBox(height: BThereSpacing.lg),
                                    AuthFlowSwitcher(
                                      signingIn: signingIn!,
                                      busy: busy,
                                    ),
                                    const SizedBox(height: BThereSpacing.lg),
                                  ] else if (backRoute != null) ...[
                                    Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: AuthBackButton(
                                        onPressed: busy
                                            ? null
                                            : () => context.go(
                                                backRoute ?? AppRoutes.auth,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: BThereSpacing.xs),
                                  ],
                                  child,
                                  if (marketing) ...[
                                    const SizedBox(height: BThereSpacing.lg),
                                    const AuthSocialButtons(),
                                    if (!signingIn!) ...[
                                      const SizedBox(height: BThereSpacing.md),
                                      AuthExistingAccountLink(busy: busy),
                                    ],
                                    const SizedBox(height: BThereSpacing.lg),
                                  ],
                                ],
                              ),
                              if (marketing) const AuthFooterLinks(),
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
      ),
    );
  }
}

class AuthFailureMessage extends StatelessWidget {
  const AuthFailureMessage(this.message, {super.key, this.decorated = false});
  final String message;
  final bool decorated;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!decorated) {
      return Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.error),
        ),
      );
    }
    return BThereInlineError(message);
  }
}

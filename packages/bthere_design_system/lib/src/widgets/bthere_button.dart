import 'package:flutter/material.dart';

import '../theme/bthere_spacing.dart';
import 'bthere_loading_indicator.dart';

enum BThereButtonVariant { primary, outlined }

class BThereButton extends StatelessWidget {
  const BThereButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.leadingIcon,
    this.trailingIcon,
    this.fullWidth = false,
    this.variant = BThereButtonVariant.primary,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  /// Requires bounded horizontal space, like standard full-width controls.
  final bool fullWidth;
  final BThereButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final callback = enabled && !loading ? onPressed : null;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading || leadingIcon != null) ...[
          if (loading)
            const ExcludeSemantics(child: BThereLoadingIndicator(size: 20))
          else
            ExcludeSemantics(child: leadingIcon!),
          const SizedBox(width: BThereSpacing.xs),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (trailingIcon != null) ...[
          const SizedBox(width: BThereSpacing.xs),
          ExcludeSemantics(child: trailingIcon!),
        ],
      ],
    );
    final button = switch (variant) {
      BThereButtonVariant.primary => FilledButton(
        onPressed: callback,
        child: child,
      ),
      BThereButtonVariant.outlined => OutlinedButton(
        onPressed: callback,
        child: child,
      ),
    };
    return SizedBox(width: fullWidth ? double.infinity : null, child: button);
  }
}

import 'package:flutter/material.dart';

import '../theme/bthere_spacing.dart';

/// Compact wrapping error announced when an operation fails.
class BThereInlineError extends StatelessWidget {
  const BThereInlineError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(BThereSpacing.sm),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(BThereSpacing.xs),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.info_outline, size: 20, color: colors.error),
            ),
            const SizedBox(width: BThereSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

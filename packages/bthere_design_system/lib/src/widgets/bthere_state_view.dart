import 'package:flutter/material.dart';

import '../theme/bthere_spacing.dart';

/// Generic state content. Callers own copy, actions, and page scrolling.
class BThereStateView extends StatelessWidget {
  const BThereStateView({
    super.key,
    required this.title,
    this.message,
    this.action,
  });
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      if (message != null) ...[
        const SizedBox(height: BThereSpacing.sm),
        Text(
          message!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
      if (action != null) ...[
        const SizedBox(height: BThereSpacing.lg),
        action!,
      ],
    ],
  );
}

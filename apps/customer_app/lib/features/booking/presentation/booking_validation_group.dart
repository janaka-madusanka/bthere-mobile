import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';

/// Keeps a validation hint beside the controls that need attention.
class BookingValidationGroup extends StatelessWidget {
  const BookingValidationGroup({super.key, required this.child, this.error});
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: CustomerColors.error.withValues(alpha: .04),
            border: Border.all(color: CustomerColors.error),
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: const TextStyle(color: CustomerColors.error, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

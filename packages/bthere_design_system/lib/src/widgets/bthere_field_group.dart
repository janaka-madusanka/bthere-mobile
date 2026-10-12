import 'package:flutter/material.dart';

import '../theme/bthere_spacing.dart';

/// An above-control label shared by text inputs, selectors and field states.
class BThereFieldGroup extends StatelessWidget {
  const BThereFieldGroup({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
      const SizedBox(height: BThereSpacing.xs),
      Semantics(label: label, child: child),
    ],
  );
}

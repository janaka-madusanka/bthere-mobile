import 'package:flutter/material.dart';

class BThereLoadingIndicator extends StatelessWidget {
  const BThereLoadingIndicator({
    super.key,
    this.size = 24,
    this.color,
    this.semanticsLabel,
  });
  final double size;
  final Color? color;

  /// Localized copy supplied by the caller for a standalone loading status.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: 3,
      color: color,
      semanticsLabel: semanticsLabel,
    ),
  );
}

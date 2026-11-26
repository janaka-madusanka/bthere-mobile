import 'package:flutter/material.dart';

import '../customer_theme.dart';

/// The fixed content sheet between Customer header and bottom navigation.
/// Clip the scrolling viewport so its corners stay rounded while scrolling.
class CustomerContentSurface extends StatelessWidget {
  const CustomerContentSurface({
    super.key,
    required this.child,
    this.color = CustomerColors.surface,
  });
  static const cornerRadius = 28.0;
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      // Match the light surround of the docked footer, including its notch.
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: cornerRadius,
        child: IgnorePointer(child: ColoredBox(color: color)),
      ),
      Material(
        color: color,
        borderRadius: BorderRadius.circular(cornerRadius),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    ],
  );
}

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

/// Quiet edge decoration, excluded from interaction and accessibility.
class AuthBackground extends StatelessWidget {
  const AuthBackground({
    super.key,
    required this.child,
    this.marketing = false,
  });
  final Widget child;
  final bool marketing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (marketing) return BThereBrandedBackground(child: child);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final width = bounds.maxWidth;
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      Positioned(
                        top: -width * 0.46,
                        right: -width * 0.32,
                        child: Container(
                          width: width * 1.05,
                          height: width * 1.05,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BThereColors.softMint.withValues(
                              alpha: dark ? 0.035 : 0.12,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -width * 0.52,
                        left: -width * 0.48,
                        child: Container(
                          width: width * 1.15,
                          height: width * 1.15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BThereColors.green.withValues(
                              alpha: dark ? 0.025 : 0.085,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: bounds.maxHeight * 0.48,
                        right: -width * 0.34,
                        child: Container(
                          width: width * 0.48,
                          height: width * 0.68,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(
                              Radius.elliptical(width, width),
                            ),
                            color: BThereColors.softMint.withValues(
                              alpha: dark ? 0.025 : 0.08,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      );
    },
  );
}

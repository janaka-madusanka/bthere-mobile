import 'package:flutter/material.dart';

import '../theme/bthere_colors.dart';

/// Decorative edge artwork shared by bright B there forms.
class BThereBrandedBackground extends StatelessWidget {
  const BThereBrandedBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = bounds.maxWidth.clamp(
        0.0,
        BThereBrandedDecoration.maxWidth,
      );
      Widget shape(double w, double h, double rotation, {bool leaf = false}) =>
          Transform.rotate(
            angle: rotation,
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: leaf
                    ? BorderRadius.only(
                        topLeft: Radius.elliptical(w, h),
                        bottomRight: Radius.elliptical(w, h),
                        topRight: Radius.circular(w * 0.2),
                        bottomLeft: Radius.circular(w * 0.2),
                      )
                    : BorderRadius.all(Radius.elliptical(w, h)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    BThereColors.softMint.withValues(alpha: 0.08),
                    BThereColors.softMint.withValues(alpha: 0.30),
                  ],
                ),
              ),
            ),
          );
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
                        left: -width * .18,
                        top: -width * .17,
                        child: shape(width * .32, width * .52, -.6),
                      ),
                      Positioned(
                        left: width * .035,
                        top: bounds.maxHeight * .14,
                        child: shape(width * .10, width * .16, -.55),
                      ),
                      Positioned(
                        right: width * .16,
                        top: bounds.maxHeight * .055,
                        child: shape(
                          width * .065,
                          width * .12,
                          -.6,
                          leaf: true,
                        ),
                      ),
                      Positioned(
                        right: -width * .19,
                        top: bounds.maxHeight * .095,
                        child: shape(width * .32, width * .35, -.3),
                      ),
                      Positioned(
                        right: width * .10,
                        top: bounds.maxHeight * .14,
                        child: shape(width * .04, width * .10, .1, leaf: true),
                      ),
                      Positioned(
                        right: width * .075,
                        top: bounds.maxHeight * .17,
                        child: shape(
                          width * .035,
                          width * .075,
                          1.2,
                          leaf: true,
                        ),
                      ),
                      Positioned(
                        right: -width * .17,
                        top: bounds.maxHeight * .27,
                        child: shape(width * .26, width * .30, -.5),
                      ),
                      Positioned(
                        left: -width * .16,
                        bottom: -width * .17,
                        child: shape(width * .32, width * .50, -.5),
                      ),
                      Positioned(
                        right: -width * .20,
                        bottom: -width * .23,
                        child: shape(width * .48, width * .34, .4),
                      ),
                      Positioned(
                        right: width * .10,
                        bottom: -width * .045,
                        child: shape(width * .10, width * .21, -.7, leaf: true),
                      ),
                      Positioned(
                        right: -width * .15,
                        bottom: width * .055,
                        child: shape(width * .22, width * .33, .5),
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

abstract final class BThereBrandedDecoration {
  static const maxWidth = 440.0;
}

import 'package:flutter/material.dart';

/// One outer page scroll; the grid sizes its rows and never owns scrolling.
class ServiceCatalogGrid extends StatelessWidget {
  const ServiceCatalogGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scaler = MediaQuery.textScalerOf(context);

      final columns = scaler.scale(14) > 19.6
          ? 1
          : scaler.scale(14) > 16.1 || bounds.maxWidth < 240
          ? 2
          : bounds.maxWidth < 300
          ? 3
          : 4;
      final tileWidth = (bounds.maxWidth - (columns - 1) * 8) / columns;
      // Reference tiles are about 158 × 202 pixels. Grow for large text.
      final referenceHeight = tileWidth * 202 / 158;
      final contentHeight = 56 + scaler.scale(12) * 1.2 * 3;
      final height = referenceHeight > contentHeight
          ? referenceHeight
          : contentHeight;
      return GridView.count(
        key: const ValueKey('service-catalog-grid'),
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: height,
        children: children,
      );
    },
  );
}

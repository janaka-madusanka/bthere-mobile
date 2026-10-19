import 'package:flutter/material.dart';

/// One outer page scroll; the grid sizes its rows and never owns scrolling.
class ServiceCatalogGrid extends StatelessWidget {
  const ServiceCatalogGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scaler = MediaQuery.textScalerOf(context);
      final scale = (MediaQuery.sizeOf(context).width / 430).clamp(.65, 1.0);

      final columns = scaler.scale(14) > 19.6
          ? 1
          : scaler.scale(14) > 16.1 || bounds.maxWidth < 240
          ? 2
          : 4;
      final tileWidth = (bounds.maxWidth - (columns - 1) * 9.5) / columns;
      // Figma's category tiles are 90 × 88; reserve two scaled label lines.
      final referenceHeight = tileWidth * 88 / 90;
      final contentHeight =
          63 * scale + scaler.scale(9.5 * scale) * (11.5 / 9.5) * 2;
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
        mainAxisSpacing: 9,
        crossAxisSpacing: 9.5,
        mainAxisExtent: height,
        children: children,
      );
    },
  );
}

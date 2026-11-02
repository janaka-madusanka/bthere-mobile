import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart';

enum BThereBrandAsset {
  carePromise('assets/branding/bthere_logo_care_promise.svg', 155, 77),
  google('assets/branding/google_logo.svg', 25, 29),
  apple('assets/branding/apple_logo.svg', 25, 29);

  const BThereBrandAsset(this.path, this.width, this.height);
  final String path;
  final double width, height;
}

/// Original artwork and viewBox proportions, with no color filter or cropping.
class BThereBrandImage extends StatelessWidget {
  const BThereBrandImage({
    super.key,
    required this.asset,
    this.width,
    this.semanticLabel,
  });
  final BThereBrandAsset asset;
  final double? width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture(
    BThereBrandAssetLoader(asset.path),
    width: width ?? asset.width,
    height: (width ?? asset.width) * asset.height / asset.width,
    fit: BoxFit.contain,
    semanticsLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}

/// These exports use a single embedded PNG through an objectBoundingBox
/// pattern. The renderer does not implement patternContentUnits; expand that
/// wrapper into equivalent SVG transforms, keeping the PNG, clip and viewBox.
class BThereBrandAssetLoader extends SvgAssetLoader {
  const BThereBrandAssetLoader(super.assetName);

  @override
  String provideSvg(ByteData? message) =>
      expandBrandImagePattern(super.provideSvg(message));
}

String expandBrandImagePattern(String source) {
  final document = XmlDocument.parse(source);
  final patterns = document.findAllElements('pattern').toList();
  for (final pattern in patterns) {
    if (pattern.getAttribute('patternContentUnits') != 'objectBoundingBox' ||
        pattern.getAttribute('width') != '1' ||
        pattern.getAttribute('height') != '1') {
      throw const FormatException('Unsupported branding pattern.');
    }
    final use = pattern.findElements('use').single;
    final fill = 'url(#${pattern.getAttribute('id')})';
    final rectangles = document
        .findAllElements('rect')
        .where((element) => element.getAttribute('fill') == fill)
        .toList();
    for (final rectangle in rectangles) {
      final x = rectangle.getAttribute('x') ?? '0';
      final y = rectangle.getAttribute('y') ?? '0';
      final width = rectangle.getAttribute('width')!;
      final height = rectangle.getAttribute('height')!;
      final replacement = XmlElement(
        XmlName.parts('g'),
        [
          XmlAttribute(
            XmlName.parts('transform'),
            'translate($x $y) scale($width $height)',
          ),
        ],
        [use.copy()],
      );
      final siblings = rectangle.parent!.children;
      siblings[siblings.indexOf(rectangle)] = replacement;
    }
    pattern.parent!.children.remove(pattern);
  }
  return document.toXmlString();
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/auth/widgets/auth_brand_image.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final asset in AuthBrandAsset.values) {
    test(
      '${asset.name} preserves original embedded artwork, clipping and viewBox and renders',
      () async {
        final source = await rootBundle.loadString(asset.path);
        final original = XmlDocument.parse(source);
        final expanded = XmlDocument.parse(expandBrandImagePattern(source));
        expect(
          expanded.rootElement.getAttribute('viewBox'),
          original.rootElement.getAttribute('viewBox'),
        );
        expect(
          expanded.findAllElements('image').single.toXmlString(),
          original.findAllElements('image').single.toXmlString(),
        );
        expect(
          expanded.findAllElements('clipPath').single.toXmlString(),
          original.findAllElements('clipPath').single.toXmlString(),
        );
        final originalRectangle = original.rootElement
            .findElements('g')
            .single
            .findElements('rect')
            .single;
        final originalUse = original.findAllElements('use').single;
        final group = expanded.rootElement
            .findElements('g')
            .single
            .findElements('g')
            .single;
        expect(
          group.getAttribute('transform'),
          'translate(${originalRectangle.getAttribute('x')} ${originalRectangle.getAttribute('y')}) scale(${originalRectangle.getAttribute('width')} ${originalRectangle.getAttribute('height')})',
        );
        expect(
          group.findElements('use').single.toXmlString(),
          originalUse.toXmlString(),
        );
        final picture = await vg.loadPicture(
          AuthBrandAssetLoader(asset.path),
          null,
        );
        expect(picture.size, Size(asset.width, asset.height));
        final image = await picture.picture.toImage(
          asset.width.toInt(),
          asset.height.toInt(),
        );
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        // Unsupported pattern exports must not silently produce a blank picture.
        var painted = 0;
        for (var offset = 3; offset < pixels.lengthInBytes; offset += 4) {
          if (pixels.getUint8(offset) != 0) painted++;
        }
        expect(painted, greaterThan(0));
        if (asset == AuthBrandAsset.carePromise) {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final preview = File('build/auth-brand-preview.png');
          await preview.parent.create(recursive: true);
          await preview.writeAsBytes(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        }
        image.dispose();
        picture.picture.dispose();
      },
    );
  }
}

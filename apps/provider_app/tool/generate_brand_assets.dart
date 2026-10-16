// Run from apps/provider_app: flutter test tool/generate_brand_assets.dart
// Rasterizes the original supplied artwork without redrawing or cropping it.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/core/presentation/brand_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate native brand assets from original logo', () async {
    final logo = await vg.loadPicture(
      const BThereBrandAssetLoader(
        'assets/branding/bthere_logo_care_promise.svg',
      ),
      null,
    );
    Future<void> render(String path, int size, double fraction) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xffffffff), BlendMode.src);
      final width = size * fraction;
      final height = width * logo.size.height / logo.size.width;
      canvas.translate((size - width) / 2, (size - height) / 2);
      canvas.scale(width / logo.size.width);
      canvas.drawPicture(logo.picture);
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }

    for (final entry in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await render(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        entry.value,
        .84,
      );
      await render(
        'android/app/src/main/res/drawable-${entry.key}/launch_logo.png',
        entry.value * 4,
        .80,
      );
    }
    await render(
      'android/app/src/main/res/drawable-xxxhdpi/brand_foreground.png',
      432,
      .60,
    );
    final contents = jsonDecode(
      await File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json')
          .readAsString(),
    );
    for (final entry in contents['images']) {
      final size =
          (double.parse(entry['size'].split('x')[0]) *
                  double.parse(entry['scale'].replaceAll('x', '')))
              .round();
      await render(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry['filename']}',
        size,
        .84,
      );
    }
    for (var scale = 1; scale <= 3; scale++) {
      await render(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${scale == 1 ? '' : '@${scale}x'}.png',
        192 * scale,
        .80,
      );
    }
    await render('build/launcher-preview.png', 1024, .84);
    logo.picture.dispose();
  });
}

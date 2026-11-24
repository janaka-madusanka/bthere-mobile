// Run from apps/customer_app: flutter test tool/generate_branding_assets.dart
// Renders the supplied SVGs with Flutter's own renderer; no new dependencies.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List rgbPng(ByteData rgba, int width, int height) {
  // iOS marketing icons must have no alpha channel, even when fully opaque.
  final rows = BytesBuilder();
  for (var y = 0; y < height; y++) {
    rows.addByte(0);
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      rows.add([
        rgba.getUint8(offset),
        rgba.getUint8(offset + 1),
        rgba.getUint8(offset + 2),
      ]);
    }
  }
  final output = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final bytes = [...ascii.encode(type), ...data];
    var crc = 0xffffffff;
    for (final b in bytes) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    final length = ByteData(4)..setUint32(0, data.length);
    final checksum = ByteData(4)..setUint32(0, crc ^ 0xffffffff);
    output
      ..add(length.buffer.asUint8List())
      ..add(bytes)
      ..add(checksum.buffer.asUint8List());
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', zlib.encode(rows.takeBytes()));
  chunk('IEND', []);
  return output.takeBytes();
}

Future<void> render(
  String svg,
  String path,
  int width,
  int height, {
  double? contentWidth,
  bool opaque = false,
}) async {
  final source = await vg.loadPicture(SvgStringLoader(svg), null);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final scale = (contentWidth ?? width) / source.size.width;
  canvas.translate(
    (width - source.size.width * scale) / 2,
    (height - source.size.height * scale) / 2,
  );
  canvas.scale(scale);
  canvas.drawPicture(source.picture);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(
    format: opaque ? ui.ImageByteFormat.rawRgba : ui.ImageByteFormat.png,
  );
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(
    opaque ? rgbPng(data!, width, height) : data!.buffer.asUint8List(),
  );
  image.dispose();
  picture.dispose();
  source.picture.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate customer native branding assets', () async {
    final icon = File('assets/branding/bthere_app_icon.svg').readAsStringSync();
    final logo = File('assets/branding/bthere_splash_logo.svg')
        .readAsStringSync();
    final foreground = icon.replaceFirst(RegExp(r'<rect[^>]*/>'), '');
    const root = 'android/app/src/main/res';
    for (final entry in {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    }.entries) {
      final scale = entry.value;
      final size = (48 * scale).round();
      await render(
        icon,
        '$root/mipmap-${entry.key}/ic_launcher.png',
        size,
        size,
      );
      final adaptive = (108 * scale).round();
      await render(
        foreground,
        '$root/mipmap-${entry.key}/ic_launcher_foreground.png',
        adaptive,
        adaptive,
        // Match the visible mark size of the legacy/iOS icon after the
        // adaptive 108 dp canvas is masked to the launcher's 72 dp viewport.
        contentWidth: 74 * scale,
      );
      await render(
        logo,
        '$root/drawable-${entry.key}/bthere_splash_logo.png',
        (240 * scale).round(),
        (91 * scale).round(),
      );
      // Android 12 masks to a 192 dp circle inside a 288 dp canvas.
      // Keep the whole wordmark inside that circle.
      await render(
        logo,
        '$root/drawable-${entry.key}/bthere_splash_android12.png',
        (288 * scale).round(),
        (288 * scale).round(),
        contentWidth: 176 * scale,
      );
    }
    const ios = 'ios/Runner/Assets.xcassets';
    final contents = jsonDecode(
      File('$ios/AppIcon.appiconset/Contents.json').readAsStringSync(),
    ) as Map;
    for (final item in contents['images'] as List) {
      final size =
          (double.parse((item['size'] as String).split('x').first) *
                  double.parse((item['scale'] as String).replaceAll('x', '')))
              .round();
      await render(
        icon,
        '$ios/AppIcon.appiconset/${item['filename']}',
        size,
        size,
        opaque: true,
      );
    }
    for (var scale = 1; scale <= 3; scale++) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      await render(
        logo,
        '$ios/LaunchImage.imageset/LaunchImage$suffix.png',
        240 * scale,
        91 * scale,
      );
    }
  });
}

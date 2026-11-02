import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Public backend-resolved marker artwork; never sends account credentials.
final customerMarkerIconLoaderProvider =
    Provider<Future<BitmapDescriptor?> Function(String)>((ref) {
      final client = http.Client();
      ref.onDispose(client.close);
      final cache = <String, Future<BitmapDescriptor?>>{};
      return (url) => cache.putIfAbsent(url, () => _load(client, url));
    });

final customerProviderPhotoMarkerLoaderProvider =
    Provider<Future<BitmapDescriptor?> Function(String)>((ref) {
      final client = http.Client();
      ref.onDispose(client.close);
      final cache = <String, Future<BitmapDescriptor?>>{};
      return (url) =>
          cache.putIfAbsent(url, () => _load(client, url, avatar: true));
    });

Future<BitmapDescriptor?> _load(
  http.Client client,
  String url, {
  bool avatar = false,
}) async {
  try {
    final uri = Uri.parse(url);
    if (!{'https', 'http'}.contains(uri.scheme) || uri.host.isEmpty) {
      return null;
    }
    final response = await client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || (response.contentLength ?? 0) > 2097152) {
      return null;
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 10),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > 2097152) return null;
    }
    final isSvg =
        uri.path.toLowerCase().endsWith('.svg') ||
        (response.headers['content-type'] ?? '').contains('image/svg');
    ui.Image image;
    if (isSvg) {
      final picture = await vg.loadPicture(
        SvgStringLoader(utf8.decode(bytes)),
        null,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(72 / picture.size.width, 72 / picture.size.height);
      canvas.drawPicture(picture.picture);
      final resized = recorder.endRecording();
      image = await resized.toImage(72, 72);
      resized.dispose();
      picture.picture.dispose();
    } else {
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        // Avoid decoding a full-resolution image just to display a small marker.
        Uint8List.fromList(bytes),
      );
      final codec = await ui.instantiateImageCodecFromBuffer(
        buffer,
        targetWidth: 72,
        targetHeight: 72,
      );
      image = (await codec.getNextFrame()).image;
      codec.dispose();
    }
    ui.Image? photoPin;
    try {
      if (avatar) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        const centre = ui.Offset(44, 44);
        canvas.drawCircle(
          centre,
          43,
          ui.Paint()..color = const ui.Color(0xFFFFFFFF),
        );
        canvas.save();
        canvas.clipPath(
          ui.Path()..addOval(const ui.Rect.fromLTWH(7, 7, 74, 74)),
        );
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          const ui.Rect.fromLTWH(7, 7, 74, 74),
          ui.Paint(),
        );
        canvas.restore();
        canvas.drawCircle(
          centre,
          42,
          ui.Paint()
            ..color = const ui.Color(0xFF008F95)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        final picture = recorder.endRecording();
        try {
          photoPin = await picture.toImage(88, 88);
        } finally {
          picture.dispose();
        }
      }
      final png = await (photoPin ?? image).toByteData(
        format: ui.ImageByteFormat.png,
      );
      return png == null
          ? null
          : BitmapDescriptor.bytes(
              png.buffer.asUint8List(),
              width: avatar ? 44 : 36,
              height: avatar ? 44 : 36,
              imagePixelRatio: 2,
            );
    } finally {
      photoPin?.dispose();
      image.dispose();
    }
  } catch (_) {
    // Invalid/unavailable artwork uses the standard Google marker.
    return null;
  }
}

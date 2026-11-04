import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/app/widgets/search_range_ripple.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('render water ripple at mid animation', () async {
    final recording = ui.PictureRecorder();
    final canvas = ui.Canvas(recording);
    const size = ui.Size(480, 480);
    canvas.drawColor(const ui.Color(0xFFDCEEDC), ui.BlendMode.src);
    final road = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..strokeWidth = 18;
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
        ui.Offset(0, 60.0 + i * 95),
        ui.Offset(480, 20.0 + i * 95),
        road,
      );
      canvas.drawLine(
        ui.Offset(40.0 + i * 100, 0),
        ui.Offset(80.0 + i * 100, 480),
        road,
      );
    }
    SearchRangeRipplePainter(
      animation: const AlwaysStoppedAnimation(.47),
      center: const Offset(240, 240),
      radius: 205,
    ).paint(canvas, size);
    canvas.drawCircle(
      const ui.Offset(240, 240),
      8,
      ui.Paint()..color = const ui.Color(0xFF008C95),
    );
    final picture = recording.endRecording();
    final image = await picture.toImage(480, 480);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('build/booking-previews/water-ripple.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}

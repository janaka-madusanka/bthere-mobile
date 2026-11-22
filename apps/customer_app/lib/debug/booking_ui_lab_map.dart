import 'package:flutter/material.dart';

import '../features/booking/presentation/customer_booking_map.dart';

/// An explicitly labelled offline renderer for the production map boundary.
/// No native map, tile downloads, geolocation or directions requests.
class BookingLabMap extends StatelessWidget {
  const BookingLabMap(this.state, {super.key});
  final CustomerMapState state;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: CustomPaint(painter: _Roads())),
      for (final marker in state.markers)
        Align(
          alignment: marker.markerId.value.contains('provider')
              ? const Alignment(-.45, -.3)
              : const Alignment(.35, .2),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(
              marker.markerId.value.contains('provider')
                  ? Icons.person_outline
                  : Icons.location_on,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      const Positioned(
        left: 10,
        bottom: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Sample map · offline',
              style: TextStyle(fontSize: 10, color: Colors.teal),
            ),
          ),
        ),
      ),
    ],
  );
}

class _Roads extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF0EE),
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * .62, -20, size.width * .5, size.height * .9),
      Paint()..color = const Color(0xFFD6EBD5),
    );
    canvas.drawOval(
      Rect.fromLTWH(-40, size.height * .45, size.width * .4, size.height),
      Paint()..color = const Color(0xFFCDEAF0),
    );
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10;
    for (var i = -2; i < 8; i++) {
      canvas.drawLine(
        Offset(i * 75.0, 0),
        Offset(i * 75.0 + 100, size.height),
        road,
      );
    }
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(0, i * 65.0),
        Offset(size.width, i * 65.0 - 45),
        road,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Roads oldDelegate) => false;
}

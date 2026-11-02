import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/customer_discovery.dart';

const catalogInk = CustomerColors.text;
const catalogMuted = CustomerColors.secondaryText;
const catalogTeal = CustomerColors.action;
const catalogPaper = CustomerColors.surface;
const catalogGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    CustomerColors.primary,
    CustomerColors.action,
    CustomerColors.primary,
  ],
);

class ServiceAppearance {
  const ServiceAppearance(this.color, this.icon);
  final Color color;
  final IconData icon;
  static ServiceAppearance forService(CustomerService service, int index) {
    final name = service.name.toLowerCase();
    if (name.contains('pet')) {
      return const ServiceAppearance(Color(0xFFF2998C), Icons.pets_rounded);
    }
    if (name.contains('child') || name.contains('baby')) {
      return const ServiceAppearance(
        Color(0xFF0F666B),
        Icons.child_care_rounded,
      );
    }
    if (name.contains('handy') || name.contains('repair')) {
      return const ServiceAppearance(Color(0xFF3E8EC7), Icons.build_rounded);
    }
    if (name.contains('vehicle') || name.contains('transport')) {
      return const ServiceAppearance(
        Color(0xFF0F666B),
        Icons.directions_car_rounded,
      );
    }
    if (name.contains('errand') || name.contains('delivery')) {
      return const ServiceAppearance(
        Color(0xFF008F95),
        Icons.shopping_bag_outlined,
      );
    }
    if (name.contains('wellness') || name.contains('lifestyle')) {
      return const ServiceAppearance(Color(0xFF62C3A0), Icons.eco_rounded);
    }
    if (name.contains('home') || name.contains('clean')) {
      return const ServiceAppearance(Color(0xFF3E8EC7), Icons.home_outlined);
    }
    if (name.contains('care') || name.contains('nurs')) {
      return const ServiceAppearance(
        Color(0xFF0F666B),
        Icons.volunteer_activism_rounded,
      );
    }
    const appearances = [
      ServiceAppearance(Color(0xFF0F666B), Icons.volunteer_activism_rounded),
      ServiceAppearance(Color(0xFF3E8EC7), Icons.home_outlined),
      ServiceAppearance(Color(0xFFF2998C), Icons.pets_rounded),
      ServiceAppearance(Color(0xFF0F666B), Icons.child_care_rounded),
    ];
    return appearances[index % appearances.length];
  }
}

class CatalogIcon extends StatelessWidget {
  const CatalogIcon({
    super.key,
    required this.appearance,
    this.url,
    this.size = 48,
  });
  final ServiceAppearance appearance;
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      appearance.icon,
      color: appearance.color,
      size: size * .57,
    );
    final uri = url == null ? null : Uri.tryParse(url!);
    final image = uri == null
        ? fallback
        : uri.path.toLowerCase().endsWith('.svg')
        ? SvgPicture.network(
            url!,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => fallback,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.network(
            url!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback,
          );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .13),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: appearance.color.withValues(alpha: .08),
      ),
      child: image,
    );
  }
}

class CatalogAccess extends StatelessWidget {
  const CatalogAccess({super.key, required this.service});
  final CustomerService service;
  @override
  Widget build(BuildContext context) {
    final available = service.accessStatus == 'ELIGIBLE';
    final color = available ? const Color(0xFF21866D) : const Color(0xFFB7791F);
    return Text(
      service.badge,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
    );
  }
}

class CatalogStatus extends StatelessWidget {
  const CatalogStatus({
    super.key,
    required this.loading,
    required this.failed,
    required this.empty,
    required this.retry,
    this.options = false,
  });
  final bool loading, failed, empty, options;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: BThereLoadingState(
          label: options ? 'Loading sub-services' : 'Loading services',
        ),
      );
    }
    if (failed) {
      return BThereStateView(
        title: options
            ? 'Unable to load sub-services'
            : 'Unable to load services',
        message: 'Please try again.',
        action: TextButton(
          onPressed: retry,
          child: Text(options ? 'Retry sub-services' : 'Retry services'),
        ),
      );
    }
    if (empty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          options
              ? 'No sub-services available for this market yet.'
              : 'No services available for this market yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: catalogMuted),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Decorative vector illustration; no sample service or customer data.
class CareBee extends StatelessWidget {
  const CareBee({super.key, this.sleeping = false});
  final bool sleeping;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _CareBeePainter(sleeping),
      size: const Size(210, 180),
    ),
  );
}

class _CareBeePainter extends CustomPainter {
  const _CareBeePainter(this.sleeping);
  final bool sleeping;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 210, size.height / 180);
    final paint = Paint()..isAntiAlias = true;
    canvas.drawOval(
      const Rect.fromLTWH(56, 155, 115, 12),
      paint
        ..color = const Color(0x14005560)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    paint.maskFilter = null;
    void oval(Rect rect, List<Color> colors) {
      paint.color = Colors.white;
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(rect);
      canvas.drawOval(rect, paint);
      paint.shader = null;
    }

    canvas.save();
    canvas.translate(127, 104);
    canvas.rotate(-.65);
    oval(const Rect.fromLTWH(0, -15, 80, 32), [
      const Color(0xFFF1FFFF),
      const Color(0xFF86DAD8),
    ]);
    canvas.rotate(.95);
    oval(const Rect.fromLTWH(0, -15, 76, 30), [
      const Color(0xFFE8FFFF),
      const Color(0xFF9FE9E3),
    ]);
    canvas.restore();
    oval(const Rect.fromLTWH(82, 88, 67, 73), [
      const Color(0xFF08AAA8),
      const Color(0xFF004B65),
    ]);
    canvas.drawArc(
      const Rect.fromLTWH(86, 105, 62, 24),
      .1,
      2.7,
      false,
      paint
        ..color = const Color(0xFFA3E1D4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    paint.style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(139, 156)
        ..lineTo(149, 170)
        ..lineTo(150, 147)
        ..close(),
      paint..color = const Color(0xFF00576C),
    );
    for (final x in [91.0, 123.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 53)
          ..quadraticBezierTo(x - 5, 22, x + 10, 16),
        paint
          ..color = const Color(0xFF00556A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      paint.style = PaintingStyle.fill;
      oval(Rect.fromCircle(center: Offset(x + 10, 16), radius: 7), [
        const Color(0xFF128E9E),
        const Color(0xFF003E5D),
      ]);
    }
    oval(const Rect.fromLTWH(54, 38, 96, 88), [
      const Color(0xFF29B5BA),
      const Color(0xFF00506C),
    ]);
    oval(const Rect.fromLTWH(56, 57, 67, 62), [
      const Color(0xFFFFFFE9),
      const Color(0xFFDBF0DF),
    ]);
    for (final eye in [const Offset(74, 81), const Offset(105, 83)]) {
      if (sleeping) {
        canvas.drawArc(
          Rect.fromCenter(center: eye, width: 12, height: 10),
          0,
          3.14,
          false,
          paint
            ..color = const Color(0xFF004F60)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        paint.style = PaintingStyle.fill;
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: eye, width: 9, height: 21),
          paint..color = const Color(0xFF004F60),
        );
        canvas.drawCircle(
          eye + const Offset(-1, -5),
          2,
          paint..color = Colors.white,
        );
      }
    }
    canvas.drawArc(
      const Rect.fromLTWH(83, 93, 15, 10),
      .2,
      2.7,
      false,
      paint
        ..color = const Color(0xFF007B80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CareBeePainter oldDelegate) =>
      sleeping != oldDelegate.sleeping;
}

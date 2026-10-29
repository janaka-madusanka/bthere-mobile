import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../onboarding/services/domain/provider_service_type.dart';

const servicesInk = Color(0xFF090E3D);
const servicesMuted = Color(0xFF8190AD);

class ServicesAsset extends StatelessWidget {
  const ServicesAsset(this.name, {super.key, this.size});
  final String name;
  final double? size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/services/new_$name.svg',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

typedef ServiceArtwork = ({Color surface, Color? badge});

ServiceArtwork serviceVisualStyle(ProviderServiceType service) {
  const palette = <Color>[
    Color(0xFFF0FCFB),
    Color(0xFFF2FAFF),
    Color(0xFFF8F4FF),
    Color(0xFFFFF8EF),
    Color(0xFFFFFBEE),
    Color(0xFFFFF4F8),
    Color(0xFFF1FCF5),
    Color(0xFFEFF3FF),
  ];
  final index = service.id.abs() % palette.length;
  return (
    surface: palette[index],
    badge: palette[(index + 1) % palette.length].withOpacity(0.55),
  );
}

class ServiceCatalogSymbol extends StatelessWidget {
  const ServiceCatalogSymbol({super.key, required this.service});
  final ProviderServiceType service;
  @override
  Widget build(BuildContext context) {
    final apiIcon = service.icon?.usableUri ?? service.usableIconUri;
    if (apiIcon != null) {
      return SizedBox(
        width: 44,
        height: 44,
        child: Image.network(
          apiIcon.toString(),
          fit: BoxFit.contain,
          semanticLabel: service.icon?.altText ?? service.name,
          errorBuilder: (_, _, _) => const Icon(
            Icons.miscellaneous_services,
            size: 32,
            color: Color(0xFF008B91),
          ),
        ),
      );
    }

    final visual = serviceVisualStyle(service);
    final name = service.name.toLowerCase();
    final icon = switch (name) {
      final n when n.contains('mobility') => Icons.assist_walker,
      final n when n.contains('transport') => Icons.directions_bus_outlined,
      final n when n.contains('medication') => Icons.medication_outlined,
      final n when n.contains('pet') => Icons.pets,
      final n when n.contains('child') => Icons.child_care,
      final n when n.contains('handyman') => Icons.build_outlined,
      final n when n.contains('garden') => Icons.eco_outlined,
      final n when n.contains('shopping') => Icons.shopping_bag_outlined,
      final n when n.contains('meal') => Icons.restaurant,
      final n when n.contains('care') => Icons.volunteer_activism_outlined,
      _ => Icons.miscellaneous_services,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: visual.badge ?? visual.surface,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(icon, size: 26, color: const Color(0xFF008B91)),
      ),
    );
  }
}

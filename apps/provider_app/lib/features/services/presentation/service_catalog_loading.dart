import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

import 'service_catalog_grid.dart';

class ServiceCatalogLoading extends StatelessWidget {
  const ServiceCatalogLoading({super.key});

  @override
  Widget build(BuildContext context) => BThereLoadingState(
    label: 'Loading services',
    message: 'Getting your services ready.',
    placeholder: ServiceCatalogGrid(
      children: List.generate(
        8,
        (_) => Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF0F2F3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            children: [
              BThereSkeleton(width: 32, height: 32, radius: 8),
              SizedBox(height: 12),
              FractionallySizedBox(
                widthFactor: .8,
                child: BThereSkeleton(height: 8),
              ),
              SizedBox(height: 6),
              FractionallySizedBox(
                widthFactor: .55,
                child: BThereSkeleton(height: 8),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

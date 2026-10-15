import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../onboarding/services/domain/provider_service_type.dart';
import 'service_catalog_visuals.dart';

class ServiceFeaturedCarousel extends StatefulWidget {
  const ServiceFeaturedCarousel({
    super.key,
    required this.services,
    required this.registered,
    required this.onSelect,
  });
  final List<ProviderServiceType> services;
  final bool registered;
  final ValueChanged<ProviderServiceType> onSelect;
  @override
  State<ServiceFeaturedCarousel> createState() =>
      _ServiceFeaturedCarouselState();
}

class _ServiceFeaturedCarouselState extends State<ServiceFeaturedCarousel> {
  final _scroll = ScrollController();
  int _active = 0;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.sizeOf(context).width / 430).clamp(.74, 1.0);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = 144 * scale + math.max(0, textScale - 1) * 65;
    final pages = math.min(5, widget.services.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24 * scale, 2, 20 * scale, 8),
          child: Semantics(
            header: true,
            child: Text(
              widget.registered ? 'My Registered Services' : '🔥  Hot Services',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: servicesInk,
              ),
            ),
          ),
        ),
        SizedBox(
          height: height + 12,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.horizontal) {
                final extent = notification.metrics.maxScrollExtent;
                final index = extent <= 0
                    ? 0
                    : (notification.metrics.pixels / extent * (pages - 1))
                          .round()
                          .clamp(0, pages - 1);
                if (index != _active) setState(() => _active = index);
              }
              return false;
            },
            child: ListView.separated(
              key: const ValueKey('featured-services'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(24 * scale, 0, 20 * scale, 12),
              itemCount: widget.services.length,
              separatorBuilder: (_, _) => SizedBox(width: 9 * scale),
              itemBuilder: (context, index) {
                final service = widget.services[index];
                final width = 161 * scale;
                return SizedBox(
                  width: width,
                  child: Semantics(
                    button: true,
                    label: 'Open ${service.name}',
                    child: Material(
                      color: Colors.white,
                      elevation: 3,
                      shadowColor: const Color(0x10293B59),
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('featured-service-${service.id}'),
                        onTap: () => widget.onSelect(service),
                        child: Column(
                          children: [
                            Expanded(
                              child: _ServicePhoto(
                                service: service,
                                registered: widget.registered,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                10 * scale,
                                8 * scale,
                                10 * scale,
                                7 * scale,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    service.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.7 * scale,
                                      height: 13 / 10.7,
                                      fontWeight: FontWeight.w700,
                                      color: servicesInk,
                                    ),
                                  ),
                                  SizedBox(height: 4 * scale),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          service.description?.trim() ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9.1 * scale,
                                            height: 12 / 9.1,
                                            color: servicesMuted,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 5 * scale),
                                      Container(
                                        width: 23 * scale,
                                        height: 23 * scale,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFA7F3E9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: ServicesAsset(
                                            'imgArrowRight',
                                            size: 16 * scale,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.services.length > 1)
          SizedBox(
            height: 20.5 * scale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < pages; index++)
                  Semantics(
                    label: 'Featured services page ${index + 1} of $pages',
                    selected: index == _active,
                    button: true,
                    child: GestureDetector(
                      onTap: () => _scroll.animateTo(
                        index / (pages - 1) * _scroll.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      child: SizedBox(
                        width: 15 * scale,
                        child: Center(
                          child: Container(
                            width: 7 * scale,
                            height: 7 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == _active
                                  ? const Color(0xFF009FA5)
                                  : const Color(0xFFDEEBF0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ServicePhoto extends StatelessWidget {
  const _ServicePhoto({required this.service, required this.registered});
  final ProviderServiceType service;
  final bool registered;
  @override
  Widget build(BuildContext context) {
    final visual = serviceVisualStyle(service);
    if (service.usableCoverUri != null) {
      return Image.network(
        service.usableCoverUri.toString(),
        fit: BoxFit.cover,
        semanticLabel: service.coverImage?.altText ?? service.name,
        errorBuilder: (_, _, _) => ColoredBox(
          color: visual.surface,
          child: Center(child: ServiceCatalogSymbol(service: service)),
        ),
      );
    }

    return ColoredBox(
      color: visual.surface,
      child: Center(child: ServiceCatalogSymbol(service: service)),
    );
  }
}

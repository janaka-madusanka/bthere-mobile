import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../onboarding/services/domain/provider_service_type.dart';
import 'service_catalog_visuals.dart';
import 'service_registration_badge.dart';
import '../domain/provider_service_status.dart';

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
                                  ? const Color(0xFF008F95)
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

/// Registered services share the page scroll and retain their existing routes.
class ServiceRegisteredGrid extends StatelessWidget {
  const ServiceRegisteredGrid({
    super.key,
    required this.services,
    required this.statuses,
    required this.onSelect,
  });
  final List<ProviderServiceType> services;
  final Map<int, ProviderServiceStatus?> statuses;
  final ValueChanged<ProviderServiceType> onSelect;

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.sizeOf(context).width / 430).clamp(.65, 1.0);
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24 * scale, 0, 20 * scale, 14 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'My Registered Services',
              style: TextStyle(
                fontSize: 15.5 * scale,
                fontWeight: FontWeight.w700,
                color: servicesInk,
              ),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, bounds) {
              final columns = scaler.scale(14) > 23 ? 1 : 2;
              final width = (bounds.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final service in services)
                    SizedBox(
                      width: width,
                      child: Material(
                        key: ValueKey(
                          'service-status-${statuses[service.id]?.name ?? "unknown"}',
                        ),
                        color: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0x18293B59),
                        borderRadius: BorderRadius.circular(11),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('featured-service-${service.id}'),
                          onTap: () => onSelect(service),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 42 * scale,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _ServicePhoto(
                                      service: service,
                                      registered: true,
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: ServiceRegistrationBadge(
                                        serviceTypeId: service.id,
                                        scale: scale,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(9 * scale),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.7 * scale,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                        color: servicesInk,
                                      ),
                                    ),
                                    SizedBox(height: 4 * scale),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            service.description?.trim() ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9.1 * scale,
                                              height: 1.3,
                                              color: servicesMuted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
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
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

const homeRegisteredTeal = Color(0xFF008F95);

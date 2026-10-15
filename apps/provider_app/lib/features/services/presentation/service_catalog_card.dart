import 'package:flutter/material.dart';

import '../../onboarding/services/domain/provider_service_type.dart';
import '../domain/provider_service_status.dart';
import 'service_status_style.dart';
import 'service_catalog_visuals.dart';

/// Presentation only; status is calculated by the existing service controllers.
class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });
  final ProviderServiceStatus? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = ServiceStatusStyle.forStatus(status);
    return Container(
      key: ValueKey('service-status-${status?.name ?? "unknown"}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            ExcludeSemantics(
              child: Icon(style.icon, size: 16, color: style.foreground),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              status?.label ?? 'Status unavailable',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelSmall
                          : Theme.of(context).textTheme.labelMedium)
                      ?.copyWith(
                        color: style.foreground,
                        fontSize: compact ? 11 : null,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceCatalogCard extends StatelessWidget {
  const ServiceCatalogCard({
    super.key,
    required this.service,
    required this.status,
    required this.onTap,
  });
  final ProviderServiceType service;
  final ProviderServiceStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(11);
    final visual = serviceVisualStyle(service);
    return Semantics(
      key: ValueKey('service-status-${status?.name ?? "unknown"}'),
      button: true,
      label: '${service.name}, ${status?.label ?? "Status unavailable"}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: visual.surface,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          key: ValueKey('main-service-${service.id}'),
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 9, 2, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ServiceCatalogSymbol(service: service),
                const SizedBox(height: 4),
                Text(
                  service.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'HomeInter',
                    letterSpacing: 0,
                    fontSize: 9.5,
                    height: 11.5 / 9.5,
                    fontWeight: FontWeight.w500,
                    color: servicesInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

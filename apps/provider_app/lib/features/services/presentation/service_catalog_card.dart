import 'package:flutter/material.dart';

import '../../onboarding/services/domain/provider_service_type.dart';
import '../domain/provider_service_status.dart';
import 'service_status_style.dart';

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
    final uri = service.usableIconUri;
    final radius = BorderRadius.circular(12);
    return Semantics(
      key: ValueKey('service-status-${status?.name ?? "unknown"}'),
      button: true,
      label: '${service.name}, ${status?.label ?? "Status unavailable"}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: .12),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: Color(0xFFF5F5F5)),
        ),
        child: InkWell(
          key: ValueKey('main-service-${service.id}'),
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: uri == null
                      ? const Icon(
                          Icons.work_outline,
                          size: 32,
                          color: Color(0xFF444444),
                        )
                      : Image.network(
                          uri.toString(),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.work_outline,
                            size: 32,
                            color: Color(0xFF444444),
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  service.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF444444),
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

import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/service_detail_controller.dart';

/// Uses the same registered/incomplete distinction as the service overview.
class ServiceRegistrationBadge extends ConsumerWidget {
  const ServiceRegistrationBadge({
    super.key,
    required this.serviceTypeId,
    required this.scale,
  });
  final int serviceTypeId;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serviceDetailControllerProvider(serviceTypeId));
    final result = state.asData?.value;
    String label = 'Registered';
    String? explanation;
    if (result is Success<ServiceDetailState>) {
      final detail = result.value;
      final available = detail.schema.options.map((o) => o.optionId).toSet();
      final registered = detail.registered
          .map((o) => o.optionId)
          .toSet()
          .intersection(available)
          .difference(detail.incompleteRegistrationIds);
      if (available.isNotEmpty) {
        label = '${registered.length}/${available.length} Registered';
      }
    } else {
      explanation = state.isLoading
          ? 'Loading registered sub-service count'
          : 'Sub-service count unavailable. Refresh services to retry.';
    }
    final badge = Container(
      key: ValueKey('service-registration-count-$serviceTypeId'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF009FA5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(color: Colors.white, fontSize: 8 * scale),
      ),
    );
    return explanation == null
        ? badge
        : Tooltip(message: explanation, child: badge);
  }
}

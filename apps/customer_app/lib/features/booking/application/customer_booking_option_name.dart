import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../discovery/data/customer_discovery_repository.dart';

typedef BookingOptionNameKey = ({
  int owner,
  int market,
  int service,
  int option,
});

String? bookingOptionName(Map<String, dynamic> booking) {
  for (final value in [
    booking['optionName'],
    booking['serviceOptionName'],
    if (booking['option'] is Map) (booking['option'] as Map)['name'],
  ]) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// History may only contain optionId. Resolve that exact option, never use the
/// category name (Caregiver) as if it were the selected option (Hospital Care).
final customerBookingOptionNameProvider = FutureProvider.autoDispose
    .family<String?, BookingOptionNameKey>(
      (ref, key) async {
        final auth = ref.watch(customerAuthControllerProvider);
        if (auth.user?.id != key.owner ||
            auth.stage != CustomerAuthStage.authenticated) {
          return null;
        }
        final options = await CustomerDiscoveryRepository(
          ref.watch(customerAuthServiceProvider),
        ).options(key.market, key.service);
        if (auth.user?.id != key.owner ||
            auth.stage != CustomerAuthStage.authenticated) {
          return null;
        }
        return options
            .where((o) => o.id == key.option && o.serviceId == key.service)
            .firstOrNull
            ?.name;
      },
      dependencies: [
        customerAuthControllerProvider,
        customerAuthServiceProvider,
      ],
    );

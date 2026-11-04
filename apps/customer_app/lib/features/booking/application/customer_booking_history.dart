import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import 'customer_booking_controller.dart';

final customerBookingHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>(
      (ref, userId) async {
        final auth = ref.watch(customerAuthControllerProvider);
        if (auth.user?.id != userId ||
            auth.stage != CustomerAuthStage.authenticated) {
          throw const CustomerAuthFailure('Please sign in again.');
        }
        final rows = await ref
            .watch(customerBookingRepositoryProvider)
            .history();
        if (auth.user?.id != userId ||
            auth.stage != CustomerAuthStage.authenticated) {
          throw const CustomerAuthFailure('Please sign in again.');
        }
        return rows;
      },
      dependencies: [
        customerAuthControllerProvider,
        customerBookingRepositoryProvider,
      ],
    );

import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../../discovery/presentation/customer_discovery_style.dart';
import '../application/customer_booking_controller.dart';
import 'booking_ui_format.dart';

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

class CustomerBookingsScreen extends ConsumerWidget {
  const CustomerBookingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthControllerProvider), id = auth.user?.id;
    final history = id == null
        ? null
        : ref.watch(customerBookingHistoryProvider(id));
    return Theme(
      data: CustomerTheme.authentication(),
      child: Scaffold(
        backgroundColor: catalogPaper,
        appBar: AppBar(
          title: const Text('My bookings'),
          leading: IconButton(
            tooltip: 'Back to Home',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: history == null
              ? const BThereLoadingState(label: 'Loading bookings')
              : history.when(
                  loading: () =>
                      const BThereLoadingState(label: 'Loading bookings'),
                  error: (_, _) => BThereStateView(
                    title: 'Unable to load bookings',
                    message: 'Please try again.',
                    action: TextButton(
                      onPressed: () =>
                          ref.invalidate(customerBookingHistoryProvider(id!)),
                      child: const Text('Retry booking history'),
                    ),
                  ),
                  data: (rows) => RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(customerBookingHistoryProvider(id!).future),
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No bookings yet.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        for (final booking in rows)
                          BookingHistoryTile(booking: booking),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class CustomerRecentBookings extends ConsumerWidget {
  const CustomerRecentBookings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthControllerProvider);
    final id = auth.user?.id;
    if (id == null) return const SizedBox.shrink();
    final history = ref.watch(customerBookingHistoryProvider(id));
    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: BThereLoadingState(
          label: 'Loading recent bookings',
          compact: true,
        ),
      ),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(customerBookingHistoryProvider(id)),
        child: const Text('Unable to load recent bookings · Retry'),
      ),
      data: (rows) => rows.isEmpty
          ? Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEBEDF5)),
              ),
              child: const Text(
                'No recent bookings yet.',
                style: TextStyle(color: catalogMuted),
              ),
            )
          : Column(
              children: [
                for (final row in rows.take(3))
                  BookingHistoryTile(booking: row),
              ],
            ),
    );
  }
}

class BookingHistoryTile extends ConsumerWidget {
  const BookingHistoryTile({super.key, required this.booking});
  final Map<String, dynamic> booking;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(customerDiscoveryProvider);
    var name = 'Service booking';
    for (final service in discovery.services) {
      if (service.id == booking['serviceTypeId']) name = service.name;
    }
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE2F7F4),
          child: Icon(Icons.event_available, color: catalogTeal),
        ),
        title: Text(
          '$name #${booking['jobId']}',
          style: const TextStyle(
            color: catalogInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${bookingDisplayTime(context, (booking['startDatetime'] ?? booking['requestedPickupTime']) as String?)}\n${booking['status']} · Payment: ${booking['paymentStatus']}',
        ),
        isThreeLine: true,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Booking #${booking['jobId']}',
                  style: const TextStyle(
                    color: catalogInk,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(name),
                Text(
                  'Total: ${booking['currencyCode']} ${booking['expectedAmount']}',
                ),
                Text(
                  'Booking: ${booking['status']}\nPayment: ${booking['paymentStatus']}',
                ),
                if (booking['startDatetime'] != null)
                  Text(
                    'Service time (market local): ${bookingDisplayTime(context, booking['startDatetime'] as String?)}',
                  ),
                if (booking['requestedPickupTime'] != null)
                  Text(
                    'Pickup (market local): ${bookingDisplayTime(context, booking['requestedPickupTime'] as String?)}',
                  ),
                if (booking['expectedEndDatetime'] != null)
                  Text(
                    'End (market local): ${bookingDisplayTime(context, booking['expectedEndDatetime'] as String?)}',
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Status is returned by the server. Cancellation and live tracking are not available in this version.',
                  style: TextStyle(color: catalogMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

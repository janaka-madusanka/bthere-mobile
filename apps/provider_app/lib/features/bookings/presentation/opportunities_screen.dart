import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../onboarding/services/application/provider_service_catalog_controller.dart';
import '../../onboarding/services/domain/provider_service_type.dart';
import '../application/booking_controller.dart';
import '../domain/booking_models.dart';
import 'booking_scaffold.dart';
import 'booking_detail_screen.dart';

class OpportunitiesScreen extends ConsumerStatefulWidget {
  const OpportunitiesScreen({super.key});
  @override
  ConsumerState<OpportunitiesScreen> createState() =>
      _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends ConsumerState<OpportunitiesScreen> {
  int selected = 0;
  DateTime? date;
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookingControllerProvider);
    final state = async.asData?.value;
    final catalog = ref.watch(providerServiceCatalogProvider).asData?.value;
    final services = catalog is Success<List<ProviderServiceType>>
        ? catalog.value
        : <ProviderServiceType>[];
    String name(int id) =>
        services.where((s) => s.id == id).firstOrNull?.name ??
        'Service request';
    final offers = state?.offers ?? <BookingOffer>[];
    final bookings = state?.bookings ?? <AssignedBooking>[];
    final accepted = bookings.where((b) => !b.completed).toList();
    final completed = bookings.where((b) => b.completed).toList();
    bool onDate(String? start) =>
        date == null ||
        start?.startsWith(date!.toIso8601String().substring(0, 10)) == true;
    return BookingScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 13, 20, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opportunities',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Find and respond to service requests that match\nyour skills and availability.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.28,
                          color: bookingMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: date == null
                      ? 'Filter by date'
                      : 'Clear date filter',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    if (date != null) {
                      setState(() => date = null);
                      return;
                    }
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (mounted && picked != null) {
                      setState(() => date = picked);
                    }
                  },
                  icon: SvgPicture.asset(
                    'assets/opportunities/imgViewCalendar.svg',
                    width: 18,
                    height: 18,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            child: BookingFilters(
              labels: [
                'All (${offers.length + bookings.length})',
                'New (${offers.length})',
                'Accepted (${accepted.length})',
                'Completed (${completed.length})',
              ],
              selected: selected,
              onSelect: (value) => setState(() => selected = value),
            ),
          ),
          const SizedBox(height: 13),
          if (state?.error != null || async.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state?.error ?? 'Unable to load requests. Pull down to retry.',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (async.hasError) {
                  ref.invalidate(bookingControllerProvider);
                  await ref.read(bookingControllerProvider.future);
                } else {
                  await ref.read(bookingControllerProvider.notifier).refresh();
                }
              },
              child: async.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(15, 0, 12, 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (selected <= 1)
                          for (final offer in offers.where(
                            (o) => onDate(o.start),
                          ))
                            OpportunityCard(
                              title: name(offer.serviceTypeId),
                              subtitle: offer.earningsLabel,
                              status: 'New',
                              start: offer.start,
                              end: offer.end,
                              address: offer.address,
                              onOpen: () => showBookingOffer(context, offer),
                              onAccept: state?.busy == true
                                  ? null
                                  : () => ref
                                        .read(
                                          bookingControllerProvider.notifier,
                                        )
                                        .decide(offer, accept: true),
                              onDecline: state?.busy == true
                                  ? null
                                  : () => ref
                                        .read(
                                          bookingControllerProvider.notifier,
                                        )
                                        .decide(offer, accept: false),
                            ),
                        if (selected != 1)
                          for (final booking
                              in (selected == 2
                                      ? accepted
                                      : selected == 3
                                      ? completed
                                      : bookings)
                                  .where((b) => onDate(b.start)))
                            OpportunityCard(
                              title: name(booking.serviceTypeId),
                              subtitle: booking.earningsLabel,
                              status: booking.completed
                                  ? 'Completed'
                                  : 'Accepted',
                              start: booking.start,
                              end: booking.end,
                              address: booking.address,
                              onOpen: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      BookingDetailScreen(jobId: booking.id),
                                ),
                              ),
                              detail: booking.statusLabel,
                            ),
                        if (offers.isEmpty && bookings.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 80,
                              horizontal: 24,
                            ),
                            child: Text(
                              'Your service requests will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: bookingMuted),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onOpen,
    this.start,
    this.end,
    this.address,
    this.onAccept,
    this.onDecline,
    this.detail,
  });
  final String title, subtitle, status;
  final String? start, end, address, detail;
  final VoidCallback onOpen;
  final VoidCallback? onAccept, onDecline;
  Widget _category() {
    final name = title.toLowerCase();
    if (name.contains('home support') || name.contains('home services')) {
      return Container(
        width: 40,
        height: 38.5,
        decoration: BoxDecoration(
          color: const Color(0xFFE2F5FF),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          'assets/opportunities/imgServiceIcon.svg',
          width: 31,
          height: 31,
        ),
      );
    }
    final asset = name.contains('meal')
        ? 'imgServiceCategory1'
        : name.contains('transport') || name.contains('vehicle')
        ? 'imgServiceCategory2'
        : name.contains('pet')
        ? 'imgServiceCategory3'
        : 'imgServiceCategory';
    return SvgPicture.asset(
      'assets/opportunities/$asset.svg',
      width: 40,
      height: 38.5,
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: Color(0xFFDADEEC), width: .7),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _category(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE5EB),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFFF1447),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: bookingTeal,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 12,
                          runSpacing: 5,
                          children: [
                            if (start != null)
                              _meta(
                                'imgAppointmentCalendar',
                                '${formatBookingTime(start!)}${end == null ? '' : ' – ${formatBookingTime(end!)}'}',
                              ),
                            if (address != null)
                              _meta('imgLocationPin', address!),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/opportunities/imgRequestDetails.svg',
                    width: 26,
                    height: 26,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      detail ?? 'New service request',
                      style: const TextStyle(fontSize: 10, color: bookingMuted),
                    ),
                  ),
                  if (status == 'New') ...[
                    _button('Decline', onDecline, false),
                    const SizedBox(width: 6),
                    _button('Accept', onAccept, true),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _meta(String asset, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SvgPicture.asset(
        'assets/opportunities/$asset.svg',
        width: 16,
        height: 16,
      ),
      const SizedBox(width: 5),
      Flexible(child: Text(text, style: const TextStyle(fontSize: 10))),
    ],
  );
  Widget _button(String label, VoidCallback? callback, bool filled) => SizedBox(
    height: 29,
    child: TextButton(
      onPressed: callback,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(61, 29),
        backgroundColor: filled ? bookingTeal : Colors.white,
        foregroundColor: filled ? Colors.white : bookingTeal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: bookingTeal, width: .6),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    ),
  );
}

String formatBookingTime(String value) =>
    value.replaceFirst('T', ' ').replaceFirst(RegExp(r':00(?:\.0+)?$'), '');

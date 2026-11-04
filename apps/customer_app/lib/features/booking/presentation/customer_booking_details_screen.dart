import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;
import '../application/customer_booking_history.dart';
import '../domain/booking_models.dart';
import 'booking_provider_details_dialog.dart';
import 'booking_ui_format.dart';

class BookingDetailsExtras {
  BookingDetailsExtras({
    required this.jobId,
    this.serviceName,
    List<ProviderCandidate> providers = const [],
    Map<String, String> answerLabels = const {},
  }) : providers = List.unmodifiable(providers),
       answerLabels = Map.unmodifiable(answerLabels);
  final int jobId;
  final String? serviceName;
  final List<ProviderCandidate> providers;
  final Map<String, String> answerLabels;
}

// Session-only display context. The booking API remains the source of truth;
// discard names/photos/field labels whenever the authenticated session changes.
final customerBookingDetailsExtrasProvider =
    Provider.family<Map<int, BookingDetailsExtras>, int>((ref, userId) {
      ref.watch(customerAuthControllerProvider);
      return <int, BookingDetailsExtras>{};
    }, dependencies: [customerAuthControllerProvider]);

class CustomerBookingDetailsScreen extends ConsumerWidget {
  const CustomerBookingDetailsScreen({
    super.key,
    required this.jobId,
    this.extras,
  });
  final int jobId;
  final BookingDetailsExtras? extras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(customerAuthControllerProvider).user?.id;
    final history = owner == null
        ? null
        : ref.watch(customerBookingHistoryProvider(owner));
    final remembered = owner == null
        ? null
        : ref.watch(customerBookingDetailsExtrasProvider(owner))[jobId];
    final supplied = remembered ?? (extras?.jobId == jobId ? extras : null);
    void retry() {
      if (owner != null) ref.invalidate(customerBookingHistoryProvider(owner));
    }

    return BookingDetailsPage(
      onBack: () =>
          context.canPop() ? context.pop() : context.go('/opportunities'),
      child: history == null
          ? const Center(child: CircularProgressIndicator())
          : history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _DetailsUnavailable(onRetry: retry),
              data: (rows) {
                final booking = rows
                    .where((row) => row['jobId'] == jobId)
                    .firstOrNull;
                if (booking == null) return _DetailsUnavailable(onRetry: retry);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(customerBookingHistoryProvider(owner!));
                    await ref.read(
                      customerBookingHistoryProvider(owner).future,
                    );
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: CustomerBookingDetailsView(
                      booking: booking,
                      serviceName: supplied?.serviceName,
                      providers: supplied?.providers ?? const [],
                      answerLabels: supplied?.answerLabels ?? const {},
                      onBookings: () => context.go('/opportunities'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Consistent Customer chrome for booking details.
class BookingDetailsPage extends StatelessWidget {
  const BookingDetailsPage({
    super.key,
    required this.onBack,
    required this.child,
  });
  final VoidCallback onBack;
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: CustomerTheme.authentication(),
    child: Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        backgroundColor: CustomerColors.action,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Booking details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(top: false, child: child),
    ),
  );
}

class _DetailsUnavailable extends StatelessWidget {
  const _DetailsUnavailable({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_note_outlined,
            size: 42,
            color: CustomerColors.action,
          ),
          const SizedBox(height: 12),
          const Text(
            'Booking details are not available yet.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry booking details'),
          ),
        ],
      ),
    ),
  );
}

String bookingStatusLabel(Object? raw) => switch (raw) {
  'CONFIRMED' => 'Confirmed',
  'IN_PROGRESS' => 'In progress',
  'COMPLETED' => 'Completed',
  'AWAITING_COMPLETION_CONFIRMATION' => 'Awaiting completion confirmation',
  'AWAITING_PAYMENT' => 'Awaiting payment',
  'PENDING' => 'Pending',
  'CANCELLED' => 'Cancelled',
  'EXPIRED' => 'Expired',
  'REJECTED' => 'Declined',
  _ => 'Status unavailable',
};

String bookingPaymentLabel(Object? raw) => switch (raw) {
  'RESERVED' => 'Funds reserved',
  'PAID' => 'Paid',
  'SETTLED' => 'Settled',
  'PENDING' => 'Pending payment',
  'FAILED' => 'Payment failed',
  'REFUNDED' => 'Refunded',
  'NOT_STARTED' => 'Not started',
  _ => 'Status unavailable',
};

class CustomerBookingDetailsView extends StatelessWidget {
  const CustomerBookingDetailsView({
    super.key,
    required this.booking,
    required this.onBookings,
    this.serviceName,
    this.providers = const [],
    this.answerLabels = const {},
  });
  final Map<String, dynamic> booking;
  final String? serviceName;
  final List<ProviderCandidate> providers;
  final Map<String, String> answerLabels;
  final VoidCallback onBookings;
  static const _ink = CustomerColors.text;

  Widget _section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFB9DEDF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              switch (title) {
                'Booking information' => Icons.event_note_rounded,
                'Payment summary' => Icons.receipt_long_outlined,
                'Your provider' ||
                'Your providers' => Icons.person_outline_rounded,
                _ => Icons.notes_rounded,
              },
              size: 23,
              color: CustomerColors.action,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 22, color: Color(0xFFE4EFEF)),
        Container(
          padding: title == 'Booking information'
              ? const EdgeInsets.all(12)
              : EdgeInsets.zero,
          decoration: title == 'Booking information'
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB9DEDF)),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 49, top: 8, bottom: 12),
                    child: Divider(height: 1, color: Color(0xFFDCE9EA)),
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final start = booking['startDatetime'] ?? booking['requestedPickupTime'];
    final end = booking['expectedEndDatetime'];
    final ids = <int>{
      if (booking['providerId'] is int) booking['providerId'] as int,
      ...((booking['providerIds'] as List?) ?? const []).whereType<int>(),
    };
    final answers = booking['answers'];
    final details = answers is Map
        ? answers.entries
              .where(
                (entry) =>
                    entry.value != null && '${entry.value}'.trim().isNotEmpty,
              )
              .toList()
        : const <MapEntry<dynamic, dynamic>>[];
    final currency = booking['currencyCode'];
    final amount = walletMoney(booking['expectedAmount'])
        .replaceFirst('Rs.', currency == 'LKR' ? 'Rs.' : '$currency');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE7F9F8), Color(0xFFD7F3F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD4EEEE)),
              ),
              child: CustomPaint(
                painter: const _DetailsHeaderWaves(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .8),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.event_available_outlined,
                              color: CustomerColors.action,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  serviceName ?? 'Service booking',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Booking #${booking['jobId']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CustomerColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DetailsBadge(
                            label: bookingStatusLabel(booking['status']),
                            primary: true,
                            subdued: {
                              'CANCELLED',
                              'REJECTED',
                              'EXPIRED',
                            }.contains(booking['status']),
                          ),
                          _DetailsBadge(
                            label: bookingPaymentLabel(
                              booking['paymentStatus'],
                            ),
                            pending: {
                              'PENDING',
                              'NOT_STARTED',
                            }.contains(booking['paymentStatus']),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _section('Booking information', [
              if (start is String)
                _DetailLine(
                  icon: Icons.calendar_today_outlined,
                  label: 'Scheduled for',
                  value: bookingDisplayTime(context, start),
                ),
              if (end is String)
                _DetailLine(
                  icon: Icons.schedule_rounded,
                  label: 'Expected end',
                  value: bookingDisplayTime(context, end),
                ),
              if (booking['meetingPointName'] case final String location)
                _DetailLine(
                  icon: Icons.place_outlined,
                  label: 'Service location',
                  value: location,
                ),
              if (booking['destinationAddress'] case final String destination)
                _DetailLine(
                  icon: Icons.flag_outlined,
                  label: 'Destination',
                  value: destination,
                ),
              _DetailLine(
                icon: Icons.room_service_outlined,
                label: 'Service mode',
                value: switch (booking['deliveryMode']) {
                  'PROVIDER_TO_CUSTOMER' => 'Provider comes to you',
                  'CUSTOMER_TO_PROVIDER' => 'Visit provider location',
                  'ONLINE' => 'Online service',
                  _ => 'Not specified',
                },
              ),
            ]),
            _section(ids.length == 1 ? 'Your provider' : 'Your providers', [
              if (ids.isEmpty)
                const Text(
                  'Provider details are not available yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: CustomerColors.secondaryText,
                  ),
                ),
              for (final id in ids)
                Builder(
                  builder: (context) {
                    final provider = providers
                        .where((p) => p.id == id)
                        .firstOrNull;
                    return Material(
                      color: const Color(0xFFF0FAF9),
                      borderRadius: BorderRadius.circular(13),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: CustomerColors.selection,
                          child: provider?.photo == null
                              ? const Icon(
                                  Icons.person_outline_rounded,
                                  color: CustomerColors.action,
                                )
                              : ClipOval(
                                  child: Image.network(
                                    provider!.photo!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person_outline_rounded,
                                      color: CustomerColors.action,
                                    ),
                                  ),
                                ),
                        ),
                        title: Text(
                          provider?.name ?? 'Assigned provider',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        subtitle: provider == null
                            ? const Text(
                                'Profile details are not available yet.',
                                style: TextStyle(fontSize: 12),
                              )
                            : const Text(
                                'View provider details',
                                style: TextStyle(fontSize: 11),
                              ),
                        trailing: provider == null
                            ? null
                            : const Icon(
                                Icons.chevron_right_rounded,
                                color: CustomerColors.action,
                              ),
                        onTap: provider == null
                            ? null
                            : () =>
                                  showBookingProviderDetails(context, provider),
                      ),
                    );
                  },
                ),
            ]),
            if (details.isNotEmpty)
              _section('Your booking details', [
                for (final entry in details)
                  _DetailLine(
                    icon: Icons.notes_rounded,
                    label:
                        answerLabels['${entry.key}'] ??
                        _humanize('${entry.key}'),
                    value: _answer(entry.value),
                  ),
              ]),
            _section('Payment summary', [
              _DetailLine(
                icon: Icons.account_balance_wallet_outlined,
                iconWidget: booking['paymentMethod'] == 'WALLET'
                    ? SvgPicture.asset(
                        'assets/icons/navigation/wallet_selected.svg',
                        width: 17,
                        height: 17,
                        colorFilter: const ColorFilter.mode(
                          CustomerColors.action,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        booking['paymentMethod'] == 'CARD'
                            ? Icons.credit_card_rounded
                            : Icons.payments_outlined,
                        size: 17,
                        color: CustomerColors.action,
                      ),
                label: 'Payment method',
                value: switch (booking['paymentMethod']) {
                  'WALLET' => 'BThere Wallet',
                  'CARD' => 'Credit / Debit Card',
                  'CASH' => 'Cash',
                  _ => 'Not specified',
                },
              ),
              _DetailLine(
                icon: Icons.receipt_long_outlined,
                label: 'Payment status',
                value: bookingPaymentLabel(booking['paymentStatus']),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CustomerColors.selection,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Booking amount',
                      style: TextStyle(
                        color: CustomerColors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            FilledButton(
              onPressed: onBookings,
              child: const Text('View all bookings'),
            ),
          ],
        ),
      ),
    );
  }

  String _humanize(String code) {
    final value = code.replaceAll('_', ' ').toLowerCase();
    return value.isEmpty
        ? 'Detail'
        : '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _answer(Object? value) => switch (value) {
    bool flag => flag ? 'Yes' : 'No',
    String text => text,
    num number => '$number',
    List values =>
      values.map((v) => v is Map ? 'Attached file' : _answer(v)).join(', '),
    Map _ => 'Attached information',
    _ => 'Not specified',
  };
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
    this.iconWidget,
  });
  final IconData icon;
  final Widget? iconWidget;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFDFF6F3),
            borderRadius: BorderRadius.circular(13),
          ),
          child:
              iconWidget ?? Icon(icon, size: 21, color: CustomerColors.action),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: CustomerColors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: CustomerColors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailsBadge extends StatelessWidget {
  const _DetailsBadge({
    required this.label,
    this.primary = false,
    this.subdued = false,
    this.pending = false,
  });
  final String label;
  final bool primary, subdued, pending;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: pending
          ? const Color(0xFFFFF1D1)
          : subdued
          ? const Color(0xFFFFE7E7)
          : primary
          ? CustomerColors.action
          : Colors.white.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pending) ...[
          const Icon(
            Icons.credit_card_rounded,
            size: 15,
            color: Color(0xFF805411),
          ),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            color: pending
                ? const Color(0xFF805411)
                : subdued
                ? const Color(0xFFB92C35)
                : primary
                ? Colors.white
                : CustomerColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DetailsHeaderWaves extends CustomPainter {
  const _DetailsHeaderWaves();
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 2; i++) {
      final offset = i * 30.0;
      final path = Path()
        ..moveTo(size.width * .55 + offset, size.height)
        ..cubicTo(
          size.width * .79 + offset,
          size.height * .94,
          size.width * .69 + offset,
          size.height * .32,
          size.width,
          size.height * .22 + offset,
        )
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF52C9C2)
              .withValues(alpha: i == 0 ? .12 : .16),
      );
    }
  }

  @override
  bool shouldRepaint(_DetailsHeaderWaves oldDelegate) => false;
}

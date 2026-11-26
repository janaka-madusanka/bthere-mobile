import '../domain/booking_option_draft.dart';
import 'booking_request_progress_screen.dart';

import 'dart:async';

import '../data/customer_request_recovery_store.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../domain/booking_card_checkout.dart';
import '../../wallet/presentation/add_test_card_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_providers.dart';
import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../wallet/application/customer_wallet_controller.dart';
import '../../wallet/data/customer_wallet_repository.dart';
import '../application/customer_booking_controller.dart';
import '../application/customer_booking_history.dart';
import '../application/customer_request_recovery.dart';
import '../application/customer_request_payment_controller.dart';
import 'booking_billing_contact_dialog.dart';
import 'booking_cancel_request_dialog.dart';
import 'booking_card_checkout_page.dart';
import 'booking_payment_visuals.dart';
import 'booking_payment_method_sheet.dart';
import 'booking_request_receipt.dart';
import 'booking_saved_cards_dialog.dart';
import 'booking_provider_accepted.dart';
import 'booking_payment_result_screen.dart';
import '../domain/booking_models.dart';

final recoveredCardCheckoutPresenterProvider =
    Provider<
      Future<void> Function(
        BuildContext,
        BookingCardCheckout,
        CustomerRequestPaymentController,
      )
    >(
      (ref) => (context, checkout, payment) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => BookingCardCheckoutPage.recovery(
              checkout: checkout,
              payment: payment,
            ),
          ),
        );
      },
    );

class CustomerRequestPaymentScreen extends ConsumerStatefulWidget {
  const CustomerRequestPaymentScreen({
    super.key,
    required this.requestId,
    this.initialRequest,
    this.provider,
    this.serviceName,
  });
  final int requestId;
  final Map<String, dynamic>? initialRequest;
  final ProviderCandidate? provider;
  final String? serviceName;
  @override
  ConsumerState<CustomerRequestPaymentScreen> createState() =>
      _CustomerRequestPaymentScreenState();
}

class _CustomerRequestPaymentScreenState
    extends ConsumerState<CustomerRequestPaymentScreen>
    with WidgetsBindingObserver {
  CustomerRequestPaymentController? payment;
  Timer? timer;
  Timer? pollingTimer;
  bool get _foreground =>
      mounted &&
      payment?.alive == true &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      ModalRoute.of(context)?.isCurrent != false;
  bool choosing = false;
  String? _publishedTerminalState;
  Map<String, dynamic>? selectedRetryCard;
  Future<Map<String, dynamic>?> _pickCard(
    CustomerRequestPaymentController c,
  ) async {
    final repository = ref.read(customerWalletRepositoryProvider);
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BookingSavedCardsDialog(
        repository: repository,
        onAddCard: () async {
          await showDialog<void>(
            context: context,
            builder: (_) => AddTestCardDialog(
              now: c.now,
              onAdd: () async {
                await repository.linkTestMethod('CARD');
                return true;
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _changeMethod() async {
    final c = payment!;
    if (choosing || !c.canPay) return;
    setState(() => choosing = true);
    try {
      final method = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheet) => BookingPaymentMethodSheet(
          currentMethod: '${c.request?['paymentMethod']}',
          onSelected: (method) => Navigator.pop(sheet, method),
        ),
      );
      if (!mounted || !c.alive || method == null) return;
      final changed = await c.changeMethod(method);
      if (!mounted || !c.alive) return;
      if (changed) {
        selectedRetryCard = null;
        if (method == 'CARD') {
          final settings = await c.settings();
          if (!mounted || !c.alive) return;
          if (settings['provider'] == 'MOCK' && settings['testMode'] == true) {
            selectedRetryCard = await _pickCard(c);
            if (!mounted || !c.alive) return;
            c.selectedCardLabel = selectedRetryCard?['displayLabel'] as String?;
          }
        }
      }
      if (mounted && c.alive) {
        ref.invalidate(customerBookingHistoryProvider(c.owner!));
        ref.read(customerRequestRecoveryProvider).refresh();
      }
    } catch (_) {
      if (mounted && c.alive) {
        c.recordPaymentFailure(
          'Unable to load payment options. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (!mounted) return;
      payment = CustomerRequestPaymentController(
        widget.requestId,
        ref.read(customerBookingRepositoryProvider),
        ref.read(customerAuthControllerProvider),
        ref.read(customerClockProvider),
        initialRequest: widget.initialRequest,
        store: CustomerRequestRecoveryStore(
          ref.read(customerMarketSelectionStoreProvider),
          ref.read(customerAuthControllerProvider).user!.id,
        ),
      );
      payment!.addListener(_changed);
      await payment!.refresh();
      if (!mounted) return;
      try {
        await ref
            .read(customerRequestRecoveryProvider)
            .remember(widget.requestId);
      } catch (_) {}
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted ||
            !payment!.alive ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.paused ||
            ModalRoute.of(context)?.isCurrent == false) {
          return;
        }
        setState(() {});
      });
      pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_foreground) payment!.refresh(background: true);
      });
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final c = payment;
    if (c == null || !c.alive || !(c.funded || c.closed)) return;
    final state = '${c.request?['status']}:${c.request?['paymentStatus']}';
    if (_publishedTerminalState == state) return;
    _publishedTerminalState = state;
    // Hosted checkout may settle after _pay returns. Publish the authoritative
    // transition observed by polling/resume as well as the initiating action.
    Future.microtask(() {
      if (!mounted || !c.alive) return;
      ref.invalidate(customerBookingHistoryProvider(c.owner!));
      ref.invalidate(customerWalletProvider);
      ref.read(customerRequestRecoveryProvider).refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) payment?.refresh(background: true);
  }

  @override
  void dispose() {
    timer?.cancel();
    pollingTimer?.cancel();
    payment?.removeListener(_changed);
    payment?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _pay() async {
    final c = payment!;
    if (choosing || !c.canPay) return;
    setState(() => choosing = true);
    try {
      int? methodId;
      String? brand, email, phone;
      var mock = false;
      if (c.request!['paymentMethod'] == 'CARD') {
        final settings = await c.settings();
        if (!mounted || !c.alive) return;
        mock = settings['provider'] == 'MOCK' && settings['testMode'] == true;
        if (mock) {
          final card = selectedRetryCard ?? await _pickCard(c);
          if (!mounted || !c.alive || card == null) return;
          methodId = card['methodId'] as int?;
          c.selectedCardLabel = card['displayLabel'] as String?;
        } else {
          // Gateway is selected by the server, never by a client gateway toggle.
          if (!{'PAYHERE', 'PAYHERE_SANDBOX'}.contains(settings['provider'])) {
            throw StateError(
              'Card payment is not configured. Please try again later.',
            );
          }
          brand = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: Colors.white,
            showDragHandle: true,
            builder: (sheet) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Choose your card type',
                      style: CustomerTypography.section,
                    ),
                  ),
                  ListTile(
                    title: const Text('Visa'),
                    onTap: () => Navigator.pop(sheet, 'VISA'),
                  ),
                  ListTile(
                    title: const Text('Mastercard'),
                    onTap: () => Navigator.pop(sheet, 'MASTER'),
                  ),
                ],
              ),
            ),
          );
          if (!mounted || !c.alive || brand == null) return;
          email = c.auth.user?.email ?? '';
          phone = c.auth.user?.phoneNumber ?? '';
          if (email.isEmpty || phone.isEmpty) {
            final contact = await showDialog<(String, String)>(
              context: context,
              builder: (_) =>
                  BookingBillingContactDialog(email: email!, phone: phone!),
            );
            if (!mounted || !c.alive || contact == null) return;
            email = contact.$1;
            phone = contact.$2;
          }
        }
      }
      final checkout = await c.pay(
        methodId: methodId,
        cardBrand: brand,
        email: email,
        phone: phone,
        mock: mock,
      );
      if (!mounted || !c.alive) return;
      if (checkout != null) {
        await ref.read(recoveredCardCheckoutPresenterProvider)(
          context,
          checkout,
          c,
        );
        if (mounted && c.alive) await c.refresh();
      }
      if (mounted && c.alive) {
        ref.invalidate(customerWalletProvider);
        ref.invalidate(customerBookingHistoryProvider(c.owner!));
        ref.read(customerRequestRecoveryProvider).refresh();
      }
    } catch (_) {
      if (mounted && c.alive) {
        c.recordPaymentFailure(
          'Unable to open payment. Please check the request status and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  Future<void> _returnToBookingForm(Map<String, dynamic> row) async {
    final c = payment;
    if (c == null || !c.alive || c.working) return;
    try {
      final input = await c.store?.draft(widget.requestId) ?? row;
      if (!mounted || !c.alive) return;
      final booking = input['booking'] is Map ? input['booking'] as Map : input;
      final service = booking['serviceTypeId'] ?? row['serviceTypeId'];
      final option = booking['optionId'] ?? row['optionId'];
      final market = ref.read(customerDiscoveryProvider).activeMarket?.id;
      if (service is! int || option is! int || market == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Choose your service to start a new booking. The previous booking form is unavailable.',
            ),
          ),
        );
        context.go('/services');
        return;
      }
      context.replace(
        '/booking/$service/$option',
        extra: recoveredBookingDraft(input, market, c.owner!),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your booking form could not be restored. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _cancel() async {
    final c = payment!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => const BookingCancelRequestDialog(),
    );
    if (!mounted || !c.alive || yes != true) return;
    await c.cancel();
    if (mounted && c.alive) {
      ref.invalidate(customerBookingHistoryProvider(c.owner!));
      ref.read(customerRequestRecoveryProvider).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = payment;
    void home() => context.go('/home');
    final busy = c?.working == true;
    if (c != null &&
        c.alive &&
        !c.loading &&
        c.request?['status'] == 'MATCHING') {
      return BookingRequestProgressView(
        matching: true,
        serviceName: widget.serviceName ?? 'your service',
        requestId: widget.requestId,
        busy: busy,
        error: c.error,
        onCancel: c.canCancel ? _cancel : null,
        onDetails: () {},
        onHome: home,
      );
    }
    if (c != null &&
        c.alive &&
        !c.loading &&
        c.request != null &&
        c.failed &&
        !c.pending &&
        !c.funded &&
        !c.closed) {
      final remaining = c.seconds;
      final urgent = remaining != null && remaining > 0 && remaining <= 30;
      final deadline = remaining == null
          ? 'Checking deadline'
          : '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';
      return BookingPaymentResultScreen(
        success: false,
        retryKeepsRequest: true,
        subtitle: 'Your payment was not completed. You can try again within the time below.',
        reason:
            c.error ??
            c.paymentFailureReason ??
            'The payment could not be completed. Please try again.',
        selectedMethod: '${c.request!['paymentMethod']}',
        selectedCardLabel: c.selectedCardLabel,
        busy: busy,
        onRetry: c.canPay && !choosing ? _pay : null,
        onDifferentMethod: c.canPay && !choosing ? _changeMethod : null,
        onHome: home,
        onBooking: () {},
        failureDetails: Container(
          key: const ValueKey('request-payment-deadline'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: urgent ? const Color(0xFFFFF4DE) : CustomerColors.selection,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                remaining == 0
                    ? 'Payment time has ended'
                    : urgent
                    ? 'Time is running out'
                    : 'Time remaining to retry',
                style: CustomerTypography.compactStrong,
              ),
              Text(
                deadline,
                style: CustomerTypography.countdown.copyWith(
                  color: urgent
                      ? CustomerColors.warning
                      : CustomerColors.action,
                ),
              ),
              Text(
                'Request #${widget.requestId}',
                style: CustomerTypography.compact,
              ),
              if (c.window == null)
                TextButton(
                  onPressed: busy ? null : () => c.refresh(),
                  child: const Text('Retry status'),
                ),
            ],
          ),
        ),
      );
    }
    return BookingPaymentPage(
      onBack: busy ? null : home,
      child: Builder(
        builder: (context) {
          if (c == null || c.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!c.alive) return const Text('Please sign in again.');
          final row = c.request;
          if (row == null) {
            return Column(
              children: [
                Text(c.error ?? 'Request unavailable'),
                TextButton(
                  onPressed: c.refresh,
                  child: const Text('Retry status'),
                ),
              ],
            );
          }
          final method = '${row['paymentMethod']}';
          final amount = row['currencyCode'] == 'LKR'
              ? walletMoney(row['expectedAmount'])
              : '${row['currencyCode']} ${row['expectedAmount']}';
          if (c.funded || c.closed) {
            return BookingRequestReceipt(
              request: row,
              busy: busy,
              onRefresh: c.refresh,
              onConfirmWallet: () {},
              onHome: home,
              onBookingForm: () => _returnToBookingForm(row),
              onBookingFilters: () => _returnToBookingForm(row),
              onBookingDetails: row['jobId'] is int
                  ? () => context.go('/bookings/${row['jobId']}')
                  : null,
            );
          }
          final remaining = c.seconds;
          final urgent = remaining != null && remaining > 0 && remaining <= 30;
          final deadline = remaining == null
              ? 'Checking deadline'
              : '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';
          if (!c.pending && row['paymentStatus'] != 'FAILED') {
            return Column(
              key: const ValueKey('booking-provider-accepted'),
              children: [
                BookingProviderAccepted(
                  serviceName: widget.serviceName ?? 'Your accepted service',
                  provider: widget.provider,
                  deadline: remaining == null ? null : deadline,
                  expired: remaining == 0,
                  busy: busy,
                  paymentEnabled: c.canPay,
                  retryPayment: c.failed,
                  availableHeight: MediaQuery.sizeOf(context).height,
                  onContinue: _pay,
                  onCancel: c.canCancel ? _cancel : null,
                  paymentAmount: amount,
                  paymentMethod: method,
                  error: c.error,
                ),
                if (c.window == null)
                  TextButton(
                    onPressed: busy ? null : () => c.refresh(),
                    child: const Text('Retry status'),
                  ),
                TextButton(
                  onPressed: busy ? null : home,
                  child: const Text('Back to Home'),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaymentArtHeading(
                title: c.pending
                    ? 'Checking your payment'
                    : c.failed
                    ? 'Payment not completed'
                    : 'Confirm your payment',
                requestId: widget.requestId,
              ),
              const SizedBox(height: 20),
              PaymentAmountArtwork(amount: amount),
              const SizedBox(height: 20),
              const Text('Payment method', style: CustomerTypography.card),
              const SizedBox(height: 10),
              PaymentSelectedMethod(
                method: method,
                showRadio: false,
                subtitle: c.selectedCardLabel,
              ),
              const SizedBox(height: 16),
              if (!c.pending)
                Container(
                  key: const ValueKey('request-payment-deadline'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: urgent
                        ? const Color(0xFFFFF4DE)
                        : CustomerColors.selection,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        urgent
                            ? 'Time is running out'
                            : 'Complete payment before',
                        style: CustomerTypography.compactStrong,
                      ),
                      Text(
                        deadline,
                        style: CustomerTypography.countdown.copyWith(
                          color: urgent
                              ? CustomerColors.warning
                              : CustomerColors.action,
                        ),
                      ),
                      const Text(
                        'Your accepted provider is kept until this deadline.',
                        style: CustomerTypography.compact,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              if (c.pending)
                const PaymentStatusNotice(
                  title: 'Waiting for payment confirmation',
                  message: 'We are checking the result. Do not make another payment.',
                  pending: true,
                ),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    c.error!,
                    style: CustomerTypography.body,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!c.pending && remaining == 0)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Payment time has ended. Checking the latest request status.',
                  ),
                ),
              if (!c.pending) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: c.canPay && !busy ? _pay : null,
                  child: busy
                      ? const CircularProgressIndicator()
                      : Text(c.failed ? 'Retry payment' : 'Confirm and Pay'),
                ),
                if (c.canCancel)
                  TextButton(
                    onPressed: busy ? null : _cancel,
                    child: const Text('Cancel request'),
                  ),
                if (c.window == null)
                  TextButton(
                    onPressed: busy ? null : () => c.refresh(),
                    child: const Text('Retry status'),
                  ),
              ],
              TextButton(
                onPressed: busy ? null : home,
                child: const Text('Back to Home'),
              ),
            ],
          );
        },
      ),
    );
  }
}

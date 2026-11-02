import 'booking_validation_group.dart';
import '../../../app/customer_providers.dart';
import '../../wallet/application/customer_wallet_controller.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;
import '../../wallet/presentation/add_test_card_dialog.dart';
import 'booking_choice_tiles.dart';
import 'booking_review_summary.dart';
import 'booking_saved_cards_dialog.dart';
import 'booking_request_progress_screen.dart';
import 'booking_payment_result_screen.dart';
import 'booking_estimated_cost.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../discovery/presentation/customer_discovery_style.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';
import '../domain/booking_option_draft.dart';
import '../../discovery/domain/customer_discovery.dart';
import 'booking_dynamic_field.dart';
import 'booking_ui_format.dart';
import 'booking_details_canvas.dart';
import 'booking_location_dialog.dart';
import 'booking_schedule_picker.dart';
import 'booking_service_details.dart';
import 'booking_provider_filters.dart';
import 'booking_provider_results_canvas.dart';
import 'customer_bookings_screen.dart';

class CustomerBookingScreen extends ConsumerStatefulWidget {
  const CustomerBookingScreen({
    super.key,
    required this.bookingKey,
    this.initialDraft,
  });
  final BookingKey bookingKey;
  final BookingOptionDraft? initialDraft;
  @override
  ConsumerState<CustomerBookingScreen> createState() =>
      _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends ConsumerState<CustomerBookingScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  CustomerBookingController? _journey;
  BookingStage? _lastStage;
  String? _lastError;
  bool _openingCard = false,
      _paymentConfirmation = false,
      _showRequestProgress = true;
  Map<String, dynamic>? _selectedPaymentCard;

  Future<bool> _bookingCard(
    CustomerBookingController c, {
    bool checkExisting = true,
  }) async {
    if (_openingCard) return false;
    setState(() => _openingCard = true);
    try {
      final repository = ref.read(customerWalletRepositoryProvider);
      final wallet = await repository.load();
      if (!mounted || !c.alive) return false;
      if (checkExisting &&
          wallet.methods.any(
            (m) => m['type'] == 'CARD' && m['status'] == 'VERIFIED_MOCK',
          )) {
        return true;
      }
      var added = false;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AddTestCardDialog(
          now: ref.read(customerClockProvider),
          unavailableReason: wallet.capabilities['cardLinking'] != true
              ? 'Card setup is not enabled yet. Please try again later.'
              : !wallet.balanced || (wallet.balance != null && !wallet.active)
              ? 'Please refresh your wallet before adding a card.'
              : null,
          onAdd: () async {
            if (!c.alive || !mounted) return false;
            if (wallet.capabilities['cardLinking'] != true ||
                !wallet.balanced) {
              return false;
            }
            if (wallet.balance == null) await repository.open();
            await repository.linkTestMethod('CARD');
            final refreshed = await repository.load();
            added = refreshed.methods.any(
              (m) => m['type'] == 'CARD' && m['status'] == 'VERIFIED_MOCK',
            );
            return added;
          },
        ),
      );
      if (!mounted || !c.alive || !added) return false;
      ref.invalidate(customerWalletProvider);
      if (c.availableMethods.contains('CARD')) {
        c.method = 'CARD';
        c.review();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Card added. Card payment is not enabled for this service yet.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card setup could not be loaded. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingCard = false);
    }
    return false;
  }

  void _showFeedback() {
    final c = _journey;
    if (c == null || !mounted) return;
    if (c.stage != BookingStage.review) _paymentConfirmation = false;
    final move =
        c.stage != _lastStage || c.error != null && c.error != _lastError;
    _lastStage = c.stage;
    _lastError = c.error;
    if (move) {
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        final c = ref.read(customerBookingProvider(widget.bookingKey));
        _journey = c;
        _lastStage = c.stage;
        c.addListener(_showFeedback);
        _loadBooking(c);
      }
    });
  }

  Future<void> _loadBooking(CustomerBookingController c) async {
    final draft = widget.initialDraft;
    final restore =
        draft != null &&
        draft.marketId == c.key.marketId &&
        draft.userId != null &&
        draft.userId == c.userId;
    if (restore) {
      c.start = draft.start;
      c.end = draft.end;
      c.point = draft.point;
      c.address = draft.address;
      c.destination = draft.destination;
      c.destinationAddress = draft.destinationAddress;
      c.radius = draft.radius;
      c.mode = draft.mode;
    }
    await c.load();
    if (!mounted || !restore || !c.alive || c.context == null) return;
    c.edit(() {
      if (!c.context!.providerFilters.any(
        (field) => field.label.toLowerCase().contains('language'),
      )) {
        c.languages.addAll(draft.languages);
      }
      c.skills.addAll(
        draft.skills.where(
          (id) => c.context!.skills.any((skill) => skill['skillId'] == id),
        ),
      );
      for (final field in c.context!.providerFilters) {
        final value = draft.filters[field.id];
        try {
          if (field.serialize(value) != null) {
            c.providerFilters[field.id] = value;
          }
        } on BookingProblem {
          // A changed option must not keep invalid preferences.
        }
      }
    });
    if (draft.serviceDetails) await c.nextServiceDetails();
  }

  void _changeService(
    CustomerBookingController c,
    CustomerServiceOption option,
  ) {
    if (c.busy ||
        !c.alive ||
        c.created != null ||
        c.uncertain ||
        option.serviceId != c.key.serviceId ||
        option.id == c.key.optionId) {
      return;
    }
    context.replace(
      '/booking/${option.serviceId}/${option.id}',
      extra: BookingOptionDraft(
        marketId: c.key.marketId,
        userId: c.userId,
        start: c.start,
        end: c.end,
        address: c.address,
        destinationAddress: c.destinationAddress,
        point: c.point,
        destination: c.destination,
        radius: c.radius,
        mode: c.mode,
        languages: Set.of(c.languages),
        skills: Set.of(c.skills),
        filters: Map.of(c.providerFilters),
        serviceDetails: {
          BookingStage.serviceDetails,
          BookingStage.results,
        }.contains(c.stage),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _journey?.removeListener(_showFeedback);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final c = ref.read(customerBookingProvider(widget.bookingKey));
      if (c.created == null &&
          !c.uncertain &&
          (c.stage == BookingStage.results || c.stage == BookingStage.review)) {
        c.refreshCheckoutOptions();
      }
    }
  }

  void _back(CustomerBookingController c) {
    if (c.busy) return;
    if (c.stage == BookingStage.review && _paymentConfirmation) {
      setState(() => _paymentConfirmation = false);
      return;
    }
    if (!c.uncertain && c.stage == BookingStage.review) {
      c.backToServiceDetails();
    } else if (!c.uncertain && c.stage == BookingStage.results) {
      c.details();
    } else if (!c.uncertain && c.stage == BookingStage.serviceDetails) {
      c.backFromServiceDetails();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/services');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(customerBookingProvider(widget.bookingKey));
    return Theme(
      data: CustomerTheme.authentication(),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) =>
            c.stage == BookingStage.created && c.paymentOutcome != null
            ? PopScope(
                canPop: !c.busy,
                child: BookingPaymentResultScreen(
                  success: c.paymentOutcome == 'SUCCESS',
                  busy: c.busy,
                  testPayment:
                      (c.created?['requestId'] == null &&
                          c.created?['paymentMethod'] == 'CARD') ||
                      {
                        'MOCK',
                        'PAYHERE_SANDBOX',
                      }.contains(c.created?['paymentFundingMode']),
                  subtitle: c.paymentOutcome != 'SUCCESS'
                      ? 'We couldn’t complete your payment. Please check the details below.'
                      : c.created?['paymentMethod'] == 'WALLET'
                      ? ((c.created?['requestId'] is int)
                            ? 'Your booking is confirmed. Wallet funds have been reserved.'
                            : 'Wallet funds have been reserved for your booking.')
                      : ((c.created?['requestId'] is int)
                            ? 'Your request has been confirmed.'
                            : 'Your test payment has been completed.'),
                  reason:
                      c.paymentFailureReason ??
                      (c.payment?['status'] == 'FAILED'
                          ? 'The test payment was not completed.'
                          : c.error),
                  onRetry: () async {
                    await c.pay();
                    if (mounted) ref.invalidate(customerWalletProvider);
                  },
                  onDifferentMethod: !c.canChangePaymentMethod
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Change payment method?'),
                              content: const Text(
                                'This will cancel the unpaid request so you can choose another payment method and send a new request. No payment will be made by this action.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Keep request'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Change method'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            await c.changeRequestPaymentMethod();
                          }
                        },
                  onBooking: c.dismissPaymentResult,
                  onHome: () => context.go('/home'),
                ),
              )
            : c.stage == BookingStage.created &&
                  c.created?['requestId'] is int &&
                  _showRequestProgress &&
                  {
                    'MATCHING',
                    'AWAITING_CUSTOMER_CONFIRMATION',
                  }.contains(c.created?['status'])
            ? BookingRequestProgressScreen(
                controller: c,
                onDetails: () => setState(() => _showRequestProgress = false),
                onCancel: !c.canCancelCreatedRequest
                    ? null
                    : () async {
                        final cancel = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Cancel request?'),
                            content: const Text(
                              'Stop finding a provider for this unpaid request?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Keep request'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Cancel request'),
                              ),
                            ],
                          ),
                        );
                        if (cancel == true && mounted) {
                          await c.cancelCreatedRequest();
                        }
                      },
              )
            : PopScope(
                canPop:
                    !c.busy &&
                    (c.uncertain ||
                        !{
                          BookingStage.review,
                          BookingStage.results,
                          BookingStage.serviceDetails,
                        }.contains(c.stage)),
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _back(c);
                },
                child: Scaffold(
                  backgroundColor: catalogTeal,
                  appBar:
                      c.context != null &&
                          {
                            BookingStage.details,
                            BookingStage.serviceDetails,
                            BookingStage.results,
                            BookingStage.review,
                          }.contains(c.stage) &&
                          !c.uncertain
                      ? null
                      : AppBar(
                          backgroundColor: catalogTeal,
                          foregroundColor: Colors.white,
                          title: const Text('Get a Service'),
                          leading: IconButton(
                            tooltip: 'Back',
                            onPressed: c.busy ? null : () => _back(c),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                  body:
                      c.context != null &&
                          c.stage == BookingStage.results &&
                          !c.uncertain
                      ? BookingProviderResultsCanvas(
                          controller: c,
                          onBack: () => _back(c),
                          onOptionChanged: (option) =>
                              _changeService(c, option),
                        )
                      : c.context != null &&
                            {
                              BookingStage.details,
                              BookingStage.serviceDetails,
                              BookingStage.review,
                            }.contains(c.stage) &&
                            !c.uncertain
                      ? BookingDetailsCanvas(
                          controller: c,
                          onBack: () => _back(c),
                          onOptionChanged: (option) =>
                              _changeService(c, option),
                          panelTitle: c.stage == BookingStage.review
                              ? 'Review your booking'
                              : c.stage == BookingStage.serviceDetails
                              ? 'Service details'
                              : 'Location and time',
                          children: c.stage == BookingStage.review
                              ? (_paymentConfirmation
                                    ? _paymentConfirmationContents(c)
                                    : _review(c))
                              : c.stage == BookingStage.serviceDetails
                              ? _details(c)
                              : _mapDetails(c),
                        )
                      : Material(
                          color: catalogPaper,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(26),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox.expand(
                            child: SafeArea(
                              top: false,
                              child: SingleChildScrollView(
                                controller: _scroll,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 720,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (c.error != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: BThereInlineError(c.error!),
                                          ),
                                        for (final e in c.fieldErrors.entries)
                                          Text(
                                            '${e.key}: ${e.value}',
                                            style: const TextStyle(
                                              color: CustomerColors.error,
                                            ),
                                          ),
                                        if (c.uncertain) ...[
                                          const Text(
                                            'Check your booking history',
                                            style: TextStyle(
                                              color: catalogInk,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          BThereButton(
                                            label: 'Open booking history',
                                            onPressed: () =>
                                                context.push('/bookings'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                context.go('/home'),
                                            child: const Text('Back to Home'),
                                          ),
                                        ] else if (c.stage ==
                                            BookingStage.invalid) ...[
                                          const Text(
                                            'Choose a service again to continue.',
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                context.go('/services'),
                                            child: const Text(
                                              'Browse services',
                                            ),
                                          ),
                                        ] else if (c.context == null) ...[
                                          if (c.busy)
                                            const BThereLoadingState(
                                              label: 'Loading service details',
                                            )
                                          else
                                            BThereButton(
                                              label: 'Retry service details',
                                              onPressed: c.load,
                                            ),
                                        ] else ...[
                                          Text(
                                            c.context!.name,
                                            style: const TextStyle(
                                              color: catalogInk,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            switch (c.stage) {
                                              BookingStage.serviceDetails =>
                                                'Service details',
                                              BookingStage.results =>
                                                'Choose your provider',
                                              BookingStage.review =>
                                                'Review your booking',
                                              BookingStage.created =>
                                                c.created?['requestId'] != null
                                                    ? 'Request submitted'
                                                    : 'Booking recorded',
                                              _ => 'Tell us what you need',
                                            },
                                            style: const TextStyle(
                                              color: catalogMuted,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          if (c.busy)
                                            const LinearProgressIndicator(),
                                          if (c.stage == BookingStage.created)
                                            ..._created(c)
                                          else if (c.stage ==
                                              BookingStage.review)
                                            ..._review(c)
                                          else
                                            ..._details(c),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
      ),
    );
  }

  List<Widget> _details(CustomerBookingController c) {
    final ctx = c.context!;
    final requirementsOnly =
        !c.allowed ||
        c.dirtyRequirements.isNotEmpty ||
        c.availability == null && c.requirements.isNotEmpty;
    return [
      if (c.requirements.isNotEmpty)
        ExpansionTile(
          initiallyExpanded: !c.allowed,
          title: const Text('Additional information'),
          subtitle: Text(
            c.allowed
                ? 'Access requirements satisfied'
                : 'A few details are needed to use this service',
          ),
          children: [
            for (final r in c.requirements)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${switch (r.status) {
                        'MISSING' => 'Please complete this detail',
                        'PENDING' => 'Submitted · awaiting review',
                        'APPROVED' => 'Approved',
                        'REJECTED' => 'Please update and resubmit',
                        'EXPIRED' => 'Expired · please update',
                        _ => r.status,
                      }}${r.blocksBooking ? ' · needed for this service' : ''}',
                      style: const TextStyle(
                        color: catalogTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (r.rejection != null)
                      Text(
                        r.rejection!,
                        style: const TextStyle(color: CustomerColors.error),
                      ),
                    BookingDynamicField(
                      key: ValueKey('requirement-${r.field.id}'),
                      field: r.field,
                      value: c.requirementAnswers[r.field.id],
                      controller: c,
                      reusable: true,
                      enabled: !c.busy,
                      onChanged: (v) => c.requirementAnswer(r.field, v),
                    ),
                    if (r.field.upload)
                      _TextEntry(
                        label: 'Expiry date (optional)',
                        value: c.expiry[r.field.id] ?? '',
                        hint: 'YYYY-MM-DD',
                        enabled: !c.busy,
                        onChanged: (v) {
                          c.expiry[r.field.id] = v;
                          c.requirementAnswer(
                            r.field,
                            c.requirementAnswers[r.field.id],
                          );
                        },
                      ),
                  ],
                ),
              ),
            BThereButton(
              label: 'Save requirement changes',
              onPressed: c.busy || c.dirtyRequirements.isEmpty
                  ? null
                  : c.saveRequirements,
            ),
            TextButton(
              onPressed: c.busy ? null : c.refreshRequirements,
              child: const Text('Check review / refresh requirements'),
            ),
          ],
        ),
      if (!c.allowed) ...[
        for (final reason in (c.access?['reasons'] as List? ?? const []))
          _Notice('${(reason as Map)['message']}'),
        if (c.requirements.isEmpty)
          TextButton(
            onPressed: c.busy ? null : c.refreshRequirements,
            child: const Text('Refresh access'),
          ),
      ],
      if (!requirementsOnly) ...[
        if (c.mode == 'PROVIDER_TO_CUSTOMER')
          BookingValidationGroup(
            error: c.fieldErrors['Service address'],
            child: ServiceDetailCard(
              label: ctx.route ? 'Pickup location' : 'Service location',
              icon: Icons.location_on,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  bookingShortAddress(c.address),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: catalogInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (ctx.route)
          BookingValidationGroup(
            error: c.fieldErrors['Destination address'],
            child: ServiceDetailCard(
              label: 'Destination',
              icon: Icons.flag_outlined,
              onEdit: c.busy
                  ? null
                  : () => _chooseLocation(c, destination: true),
              child: _TextEntry(
                label: 'Destination address',
                value: c.destinationAddress,
                enabled: !c.busy,
                onChanged: (v) => c.edit(() => c.destinationAddress = v),
              ),
            ),
          ),
        BookingServiceFields(controller: c),
        BookingServiceSchedule(
          controller: c,
          onEdit: c.busy ? null : c.details,
        ),
        if (!requirementsOnly) BookingPricingChoices(controller: c),
      ],
      Row(
        key: const ValueKey('booking-details-footer'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!requirementsOnly) ...[
            Expanded(
              flex: 6,
              child: BookingEstimatedCost(
                controller: c,
                showPricingChoices: false,
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 5,
            child: BThereButton(
              key: const ValueKey('booking-find-providers'),
              label: requirementsOnly
                  ? c.allowed
                        ? 'Choose location and time'
                        : 'Check available providers'
                  : 'Continue',
              loading: c.busy,
              onPressed:
                  c.busy ||
                      !c.allowed ||
                      (requirementsOnly && c.dirtyRequirements.isNotEmpty)
                  ? null
                  : requirementsOnly
                  ? c.details
                  : c.continueServiceDetails,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _review(CustomerBookingController c) => [
    BookingReviewSummary(
      controller: c,
      onEdit: c.busy ? null : c.backToServiceDetails,
    ),
    for (final field in c.context!.providerFilters.where(
      (f) => c.context!.pricingFieldIds.contains(f.id),
    ))
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          key: ValueKey(
            'pricing-choice-${field.id}-${c.pricingSelections[field.id]}',
          ),
          initialValue: c.pricingSelections[field.id],
          decoration: InputDecoration(labelText: '${field.label} (pricing)'),
          items: [
            for (final choice in field.options)
              DropdownMenuItem(
                value: choice['value'],
                child: Text(choice['label']!),
              ),
          ],
          onChanged: c.busy
              ? null
              : (value) => c.choosePricing(field.id, value),
        ),
      ),
    if (c.quote?['pricingSnapshot'] case final Map snapshot)
      for (final entry in const {
        'baseFare': 'Base fare',
        'pricePerKm': 'Per km',
        'minimumFare': 'Minimum fare',
        'rate': 'Configured rate',
      }.entries)
        if (snapshot[entry.key] is num)
          ListTile(
            dense: true,
            title: Text(entry.value),
            trailing: Text(
              '${c.quote!['currencyCode']} ${snapshot[entry.key]}',
            ),
          ),
    if (!c.isOpenRequest && c.quote == null)
      OutlinedButton(
        key: const ValueKey('booking-quote'),
        onPressed: c.busy || c.method == null ? null : c.previewQuote,
        child: const Text('Preview price'),
      ),
    if (c.paymentError != null) _Notice(c.paymentError!),
    if (c.availableMethods.isNotEmpty)
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 6),
        child: Text(
          'Choose a payment method',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: catalogInk,
          ),
        ),
      ),
    for (final payment in c.availableMethods)
      RadioGroup<String>(
        groupValue: c.method,
        onChanged: (v) {
          c.method = v;
          c.review();
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RadioListTile<String>(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: c.method == payment
                    ? const Color(0xFF008F96)
                    : const Color(0xFFE3ECEE),
              ),
            ),
            selected: c.method == payment,
            selectedTileColor: const Color(0xFFE7F8F8),
            secondary: payment == 'CARD'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/payment/mastercard.svg',
                        width: 20,
                        height: 16,
                      ),
                      const SizedBox(width: 6),
                      SvgPicture.asset(
                        'assets/icons/payment/visa.svg',
                        width: 24,
                        height: 16,
                      ),
                    ],
                  )
                : Icon(
                    payment == 'WALLET'
                        ? Icons.account_balance_wallet_outlined
                        : Icons.payments_outlined,
                    color: catalogTeal,
                    size: 20,
                  ),
            title: Text(
              switch (payment) {
                'CARD' => 'Credit / Debit Card',
                'WALLET' => 'BThere Wallet',
                'CASH' => 'Cash on Hand',
                _ => payment,
              },
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(switch (payment) {
              'CARD' =>
                c.usesRequestPolicy
                    ? 'Pay after provider acceptance'
                    : 'Use your saved test card',
              'WALLET' => 'Use your available wallet balance',
              'CASH' => 'Pay the provider after the service',
              _ => '',
            }, style: const TextStyle(fontSize: 10)),
            value: payment,
            enabled: !c.busy,
          ),
        ),
      ),
    const SizedBox(height: 6),
    Row(
      key: const ValueKey('booking-review-footer'),
      children: [
        Expanded(
          flex: 6,
          child: c.isOpenRequest
              ? BookingEstimatedCost(
                  controller: c,
                  showPricingChoices: false,
                  compact: true,
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF9F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated total',
                        style: TextStyle(fontSize: 12, color: catalogMuted),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        c.quote == null
                            ? 'Preview price to see total'
                            : c.quote!['currencyCode'] == 'LKR'
                            ? walletMoney(c.quote!['expectedAmount'])
                            : '${c.quote!['currencyCode']} ${c.quote!['expectedAmount']}',
                        style: TextStyle(
                          fontSize: c.quote == null ? 11 : 16,
                          fontWeight: FontWeight.w700,
                          color: catalogInk,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: FilledButtonTheme(
            data: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            child: BThereButton(
              key: const ValueKey('booking-create'),
              label: 'Continue',
              loading: c.busy || _openingCard,
              onPressed: c.busy || _openingCard
                  ? null
                  : () => _continueToPayment(c),
            ),
          ),
        ),
      ],
    ),
  ];

  Future<bool> _selectPaymentCard(CustomerBookingController c) async {
    final card = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BookingSavedCardsDialog(
        repository: ref.read(customerWalletRepositoryProvider),
        onAddCard: () async {
          await _bookingCard(c, checkExisting: false);
        },
      ),
    );
    if (!mounted || !c.alive || card == null) return false;
    setState(() => _selectedPaymentCard = card);
    return true;
  }

  Future<void> _continueToPayment(CustomerBookingController c) async {
    if (c.method == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            c.availableMethods.isEmpty
                ? 'Payments are not enabled for this service yet. Please contact support.'
                : 'Choose a payment method to continue.',
          ),
        ),
      );
      return;
    }
    if (c.method == 'CARD' && !await _selectPaymentCard(c)) return;
    if (!mounted || !c.alive) return;
    setState(() => _paymentConfirmation = true);
  }

  Future<void> _confirmBookingAndPay(CustomerBookingController c) async {
    if (c.busy || !c.alive || !c.availableMethods.contains(c.method)) return;
    if (c.method == 'CARD' &&
        _selectedPaymentCard == null &&
        !await _selectPaymentCard(c)) {
      return;
    }
    if (!mounted || !c.alive) return;
    _showRequestProgress = true;
    await c.submit();
    if (!mounted || !c.alive) return;
    if (c.created != null &&
        c.created!['requestId'] == null &&
        c.created!['paymentMethod'] == 'WALLET') {
      await c.pay();
      if (mounted) ref.invalidate(customerWalletProvider);
    }
    if (mounted && c.created != null && c.userId != null) {
      ref.invalidate(customerBookingHistoryProvider(c.userId!));
    }
  }

  List<Widget> _paymentConfirmationContents(CustomerBookingController c) => [
    const Text(
      'Payment',
      key: ValueKey('booking-payment-confirmation'),
      style: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: catalogInk,
      ),
    ),
    const SizedBox(height: 10),
    BookingEstimatedCost(controller: c, showPricingChoices: false),
    const SizedBox(height: 10),
    const Text(
      'Choose a payment method',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: catalogInk,
      ),
    ),
    const SizedBox(height: 8),
    RadioGroup<String>(
      groupValue: c.method,
      onChanged: (value) async {
        if (c.busy) return;
        final previous = c.method;
        if (value == 'CARD' && !await _selectPaymentCard(c)) return;
        if (!mounted || !c.alive) return;
        c.method = value ?? previous;
        c.review();
      },
      child: Column(
        children: [
          for (final method in c.availableMethods)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RadioListTile<String>(
                value: method,
                enabled: !c.busy,
                dense: true,
                selected: c.method == method,
                selectedTileColor: const Color(0xFFE7F8F8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: c.method == method
                        ? catalogTeal
                        : CustomerColors.border,
                  ),
                ),
                title: Text(
                  switch (method) {
                    'CARD' => 'Credit / Debit Card',
                    'WALLET' => 'BThere Wallet',
                    _ => 'Cash on Hand',
                  },
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  method == 'CARD'
                      ? (_selectedPaymentCard?['displayLabel'] as String? ??
                            'Select a saved card')
                      : method == 'WALLET'
                      ? 'Use your available wallet balance'
                      : 'Pay after service',
                  style: const TextStyle(fontSize: 11),
                ),
                secondary: method == 'CARD'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/payment/mastercard.svg',
                            width: 22,
                            height: 18,
                          ),
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            'assets/icons/payment/visa.svg',
                            width: 26,
                            height: 18,
                          ),
                        ],
                      )
                    : Icon(
                        method == 'WALLET'
                            ? Icons.account_balance_wallet_outlined
                            : Icons.payments_outlined,
                        color: catalogTeal,
                      ),
              ),
            ),
        ],
      ),
    ),
    if (c.usesRequestPolicy)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'You won’t be charged until a provider accepts. You’ll confirm payment after acceptance.',
          style: TextStyle(fontSize: 12, color: catalogMuted),
        ),
      ),
    TextButton(
      onPressed: c.busy
          ? null
          : () => setState(() => _paymentConfirmation = false),
      child: const Text('Back to booking review'),
    ),
    BThereButton(
      key: const ValueKey('booking-confirm-and-pay'),
      label: 'Confirm and Pay',
      loading: c.busy,
      onPressed: c.busy ? null : () => _confirmBookingAndPay(c),
    ),
  ];

  Future<void> _chooseLocation(
    CustomerBookingController c, {
    bool destination = false,
  }) async {
    final result = await Navigator.of(context).push<(GeoPoint, String)>(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: CustomerTheme.authentication(),
          child: BookingLocationDialog(
            point: destination ? c.destination : c.point,
            address: destination ? c.destinationAddress : c.address,
            radius: c.radius,
            title: destination ? 'Choose destination' : 'Service location',
            countryCode: c.discovery.activeMarket?.countryCode,
          ),
        ),
      ),
    );
    if (!mounted || result == null || !c.alive) return;
    c.edit(() {
      if (destination) {
        c.destination = result.$1;
        c.destinationAddress = result.$2;
      } else {
        c.point = result.$1;
        c.address = result.$2;
      }
    });
  }

  Widget _matchingPreferences(CustomerBookingController c) => Column(
    children: [
      Wrap(
        spacing: 8,
        children: [
          for (final skill in c.context!.skills)
            FilterChip(
              label: Text('${skill['name']}'),
              selected: c.skills.contains(skill['skillId']),
              onSelected: c.busy
                  ? null
                  : (on) => c.edit(
                      () => on
                          ? c.skills.add(skill['skillId'] as int)
                          : c.skills.remove(skill['skillId']),
                    ),
            ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Providers must meet every selected language and skill.',
          style: TextStyle(color: catalogMuted, fontSize: 12),
        ),
      ),
    ],
  );

  Future<void> _chooseRadius(CustomerBookingController c) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Search radius · ${c.radius.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  key: const ValueKey('booking-radius'),
                  value: c.radius.clamp(.1, 50),
                  min: .1,
                  max: 50,
                  divisions: 499,
                  label: '${c.radius.toStringAsFixed(1)} km',
                  onChanged: c.busy
                      ? null
                      : (v) {
                          c.edit(() => c.radius = v);
                          update(() {});
                        },
                ),
                BThereButton(
                  label: 'Done',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _locationRadius(CustomerBookingController c) => LayoutBuilder(
    builder: (context, bounds) {
      Widget tile(
        String title,
        String value,
        IconData icon,
        Key key,
        VoidCallback? tap,
      ) => OutlinedButton(
        key: key,
        onPressed: tap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: CustomerColors.selection,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: catalogTeal, size: 22),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10, color: catalogMuted),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: catalogInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (title == 'Location')
              const Icon(Icons.chevron_right, color: catalogMuted, size: 18),
          ],
        ),
      );
      final location = tile(
        'Location',
        c.address.isNotEmpty
            ? bookingShortAddress(c.address)
            : c.point == null
            ? 'Choose location'
            : 'Selected on map',
        Icons.location_on,
        const ValueKey('booking-choose-location'),
        c.busy ? null : () => _chooseLocation(c),
      );
      final radius = tile(
        'Radius',
        '${c.radius.toStringAsFixed(1)} km',
        Icons.adjust,
        const ValueKey('booking-radius-picker'),
        c.busy ? null : () => _chooseRadius(c),
      );
      return bounds.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(14) <= 20
          ? Row(
              children: [
                Expanded(flex: 3, child: location),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: radius),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [location, const SizedBox(height: 8), radius],
            );
    },
  );

  List<Widget> _mapDetails(CustomerBookingController c) => [
    if (c.context!.providerFilters.isNotEmpty)
      BookingProviderFilters(controller: c),
    if (c.mode != 'ONLINE') ...[
      BookingValidationGroup(
        key: const ValueKey('booking-location-validation'),
        error: c.fieldErrors['Location'],
        child: _locationRadius(c),
      ),
      if (c.context!.route)
        BookingValidationGroup(
          error: c.fieldErrors['Destination'],
          child: OutlinedButton.icon(
            onPressed: c.busy
                ? null
                : () => _chooseLocation(c, destination: true),
            icon: const Icon(Icons.flag_outlined),
            label: Text(
              c.destinationAddress.isEmpty
                  ? 'Choose destination on map'
                  : bookingShortAddress(c.destinationAddress),
            ),
          ),
        ),
      const SizedBox(height: 8),
    ],
    BookingValidationGroup(
      key: const ValueKey('booking-schedule-validation'),
      error:
          c.fieldErrors['Start time'] ??
          c.fieldErrors['Duration'] ??
          c.fieldErrors['Schedule'],
      child: BookingSchedulePicker(controller: c),
    ),
    if (!c.context!.providerFilters.any(
      (field) => field.label.toLowerCase().contains('language'),
    )) ...[
      const SizedBox(height: 10),
      BookingValidationGroup(
        key: const ValueKey('booking-language-validation'),
        error: c.fieldErrors['Language'],
        child: BookingChoiceTiles(
          choices: const [
            {'value': 'SINHALA', 'label': 'Sinhala'},
            {'value': 'ENGLISH', 'label': 'English'},
            {'value': 'TAMIL', 'label': 'Tamil'},
          ],
          selected: c.languages,
          enabled: !c.busy,
          onChanged: (value, on) => c.edit(() {
            if (on) {
              c.languages.add(value);
            } else {
              c.languages.remove(value);
            }
          }),
        ),
      ),
    ],
    if (c.context!.skills.isNotEmpty) ...[
      const SizedBox(height: 10),
      BookingValidationGroup(
        key: const ValueKey('booking-skills-validation'),
        error: c.fieldErrors['Skills'],
        child: _matchingPreferences(c),
      ),
    ],
    BThereButton(
      key: const ValueKey('booking-location-continue'),
      label: 'Continue',
      loading: c.busy,
      onPressed: c.busy ? null : c.nextServiceDetails,
    ),
  ];

  List<Widget> _created(CustomerBookingController c) {
    final b = c.created!;
    if (b['requestId'] is int) {
      final paid =
          b['status'] == 'CONFIRMED' &&
          {'RESERVED', 'PAID', 'SETTLED'}.contains(b['paymentStatus']);
      return [
        Icon(
          paid ? Icons.task_alt : Icons.pending_actions_rounded,
          color: catalogTeal,
          size: 56,
        ),
        const SizedBox(height: 16),
        Text(
          'Request #${b['requestId']}',
          style: const TextStyle(
            color: catalogInk,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        _Notice('Request: ${b['status']}\nPayment: ${b['paymentStatus']}'),
        if (b['expectedAmount'] != null)
          _Notice(
            'Expected total: ${b['currencyCode']} ${b['expectedAmount']}',
          ),
        if (!paid)
          _Notice(switch (b['status']) {
            'MATCHING' => 'Waiting for provider acceptance. Payment can be confirmed after a provider accepts.',
            'AWAITING_CUSTOMER_CONFIRMATION' => 'A provider has accepted. Confirm your payment before the confirmation deadline.',
            'PAYMENT_PENDING' => 'Payment confirmation is pending. Refresh the request status to check the result.',
            _ => 'Check the request and payment status before continuing.',
          }),
        if (b['paymentMethod'] == 'WALLET' &&
            b['status'] == 'AWAITING_CUSTOMER_CONFIRMATION')
          BThereButton(
            key: const ValueKey('booking-confirm-wallet'),
            label: 'Confirm and Pay with Wallet',
            loading: c.busy,
            onPressed: c.busy
                ? null
                : () async {
                    await c.confirmRequestWallet();
                    if (mounted) ref.invalidate(customerWalletProvider);
                  },
          ),
        BThereButton(
          label: 'Refresh request status',
          loading: c.busy,
          onPressed: c.busy ? null : c.refreshCreatedRequest,
        ),
        TextButton(
          onPressed: () => context.go('/home'),
          child: const Text('Back to Home'),
        ),
      ];
    }
    return [
      const Icon(Icons.task_alt, color: catalogTeal, size: 68),
      const SizedBox(height: 16),
      Text(
        'Booking #${b['jobId']}',
        style: const TextStyle(
          color: catalogInk,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      _Notice(
        'Total: ${b['currencyCode']} ${b['expectedAmount']}\nBooking: ${b['status']}\nPayment: ${b['paymentStatus']}',
      ),
      const _Notice(
        'A recorded booking is not provider acceptance. Payment status is shown separately.',
      ),
      if (b['paymentMethod'] == 'CASH')
        const _Notice(
          'Cash payment remains pending. Pay the provider according to your service arrangement.',
        ),
      if ({'CARD', 'WALLET'}.contains(b['paymentMethod']) &&
          b['paymentStatus'] == 'PENDING')
        BThereButton(
          label: b['paymentMethod'] == 'WALLET'
              ? 'Reserve wallet funds'
              : 'Create test card payment session',
          loading: c.busy,
          onPressed: c.busy
              ? null
              : () async {
                  await c.pay();
                  if (mounted && c.userId != null) {
                    ref.invalidate(customerBookingHistoryProvider(c.userId!));
                  }
                },
        ),
      if (c.payment != null)
        _Notice(
          'Payment operation: ${c.payment!['status']}${b['paymentMethod'] == 'WALLET' ? '\nA reservation is not final settlement.' : '\nThis is a test card session. No real card charge was made.'}',
        ),
      if (b['paymentMethod'] == 'CARD' && c.payment?['intentId'] is int)
        Wrap(
          spacing: 8,
          children: [
            for (final outcome
                in c.payment!['status'] == 'PENDING'
                    ? ['SUCCESS', 'FAILURE']
                    : c.payment!['status'] == 'SUCCEEDED'
                    ? ['REFUND']
                    : <String>[])
              OutlinedButton(
                onPressed: c.busy
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Test payment only'),
                            content: Text(
                              'Simulate $outcome for this mock card session? No real money is moved.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Simulate'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          await c.mockPayment(outcome);
                          if (mounted && c.userId != null) {
                            ref.invalidate(
                              customerBookingHistoryProvider(c.userId!),
                            );
                          }
                        }
                      },
                child: Text('Simulate test ${outcome.toLowerCase()}'),
              ),
          ],
        ),
      const SizedBox(height: 12),
      BThereButton(
        label: 'My bookings',
        onPressed: c.busy ? null : () => context.push('/bookings'),
      ),
      TextButton(
        onPressed: c.busy ? null : () => context.go('/home'),
        child: const Text('Back to Home'),
      ),
    ];
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEBF7F7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(color: catalogInk, fontSize: 14),
    ),
  );
}

class _TextEntry extends StatefulWidget {
  const _TextEntry({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });
  final String label, value;
  final String? hint;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  State<_TextEntry> createState() => _TextEntryState();
}

class _TextEntryState extends State<_TextEntry> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  @override
  void didUpdateWidget(_TextEntry old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
      onChanged: widget.onChanged,
    ),
  );
}

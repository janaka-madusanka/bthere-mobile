import 'package:flutter/services.dart';

import '../../profile/presentation/service_documents_screen.dart';
import '../../profile/presentation/profile_document_sheet.dart';
import 'booking_checkout_contents.dart';
import 'booking_ride_details.dart';
import 'customer_request_payment_screen.dart';
import 'booking_request_receipt.dart';
import 'booking_payment_visuals.dart';
import 'customer_booking_details_screen.dart';
import 'booking_cancel_request_dialog.dart';
import 'booking_validation_group.dart';
import '../../../app/customer_providers.dart';
import '../../wallet/application/customer_wallet_controller.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;
import '../../wallet/presentation/add_test_card_dialog.dart';
import 'booking_choice_tiles.dart';
import 'booking_review_summary.dart';
import 'booking_saved_cards_dialog.dart';
import 'booking_request_progress_screen.dart';
import 'booking_card_checkout_page.dart';
import 'booking_billing_contact_dialog.dart';
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
import 'booking_location_picker.dart' show customerDeviceLocationProvider;
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
  int _rideLocationStep = 0;
  CustomerBookingController? _journey;
  Future<GeoPoint>? _initialLocation;
  BookingStage? _lastStage;
  String? _lastError;
  bool _openingCard = false,
      _paymentConfirmation = false,
      _showRequestProgress = true;
  Map<String, dynamic>? _selectedPaymentCard;
  String? _replacementMethod;

  String get _selectedCardSummary {
    final label = '${_selectedPaymentCard?['displayLabel'] ?? ''}';
    final savedLast4 = _selectedPaymentCard?['last4'];
    final last4 =
        savedLast4 is String && RegExp(r'^\d{4}$').hasMatch(savedLast4)
        ? savedLast4
        : RegExp(r'(\d{4})\s*$').firstMatch(label)?.group(1);
    if (last4 == null) return 'Your selected card';
    return '•••• $last4${label.toUpperCase().contains('TEST') ? ' · Test card' : ''}';
  }

  void _openCompletedBooking(CustomerBookingController c) {
    if (!mounted || !c.alive || c.busy) return;
    final jobId = c.created?['jobId'];
    if (jobId is! int || jobId <= 0) {
      c.dismissPaymentResult();
      return;
    }
    final extras = BookingDetailsExtras(
      jobId: jobId,
      serviceName: c.context?.name,
      providers: {
        for (final provider in [
          ...c.candidates,
          ...c.availableCandidates,
          ...c.selected.values,
        ])
          provider.id: provider,
      }.values.toList(),
      answerLabels: {
        for (final field in c.context?.fields ?? <BookingField>[])
          field.code: field.label,
      },
    );
    c.dismissPaymentResult();
    if (c.userId != null) {
      ref.read(customerBookingDetailsExtrasProvider(c.userId!))[jobId] = extras;
      ref.invalidate(customerBookingHistoryProvider(c.userId!));
    }
    context.go('/bookings/$jobId', extra: extras);
  }

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
      // Card setup only updates the saved-card list. The caller owns booking
      // selection and navigation, including payment-failure recovery.
      return added;
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
      c.bookNow = draft.bookNow;
      c.start = draft.start;
      c.end = draft.end;
      c.point = draft.point;
      c.address = draft.address;
      c.destination = draft.destination;
      c.destinationAddress = draft.destinationAddress;
      c.radius = draft.radius;
      c.mode = draft.mode;
    }
    await c.load(
      onContextReady: (details) {
        if (!mounted ||
            !c.alive ||
            c.point != null ||
            _initialLocation != null) {
          return;
        }
        final mode = details.modes.contains(c.mode)
            ? c.mode
            : details.modes.contains('PROVIDER_TO_CUSTOMER')
            ? 'PROVIDER_TO_CUSTOMER'
            : details.modes.first;
        if (mode == 'ONLINE') return;
        // Start the same fresh GPS read while remaining service APIs load, then
        // hand it to the picker. Do not override a manually chosen/draft pin.
        _initialLocation = ref.read(customerDeviceLocationProvider)();
        _initialLocation!.ignore();
      },
    );
    if (!mounted || !restore || !c.alive || c.context == null) return;
    if (draft.bookNow && !c.context!.instantBooking) c.chooseBookNow(false);
    c.edit(() {
      if (!c.context!.providerFilters.any(
        (field) => field.label.toLowerCase().contains('language'),
      )) {
        c.languages.addAll(draft.languages.take(1));
      }
      c.skills.addAll(
        draft.skills.where(
          (id) => c.context!.skills.any((skill) => skill['skillId'] == id),
        ),
      );
      for (final field in c.context!.providerFilters) {
        final saved = draft.filters[field.id];
        final value =
            field.label.toLowerCase().contains('language') && saved is List
            ? saved.take(1).toList()
            : saved;
        try {
          if (field.serialize(value) != null) {
            c.providerFilters[field.id] = value;
          }
        } on BookingProblem {
          // A changed option must not keep invalid preferences.
        }
      }
    });
    c.edit(() {
      for (final field in c.context!.fields) {
        if (draft.answersById.containsKey(field.id)) {
          c.answers[field.code] = draft.answersById[field.id];
        }
      }
      c.note = draft.customerNote;
      if (c.availableMethods.contains(draft.paymentMethod)) {
        c.method = draft.paymentMethod;
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
        bookNow: c.bookNow,
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
    if (c.context?.route == true &&
        c.stage == BookingStage.details &&
        _rideLocationStep > 0) {
      setState(() => _rideLocationStep = 0);
      return;
    }
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

  Future<void> _refreshServiceDocuments(CustomerBookingController c) async {
    await c.refreshRequirements();
    if (mounted && c.alive && c.allowed && c.context == null) {
      await _loadBooking(c);
    }
  }

  Widget _documentGate(CustomerBookingController c) {
    final documents = c.requirements
        .where(
          (r) => r.field.upload && !{'APPROVED', 'PROVIDED'}.contains(r.status),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: CustomerColors.primary,
        title: Text(
          'My documents',
          style: CustomerTypography.section.copyWith(color: Colors.black),
        ),
      ),
      body: SafeArea(
        top: false,
        child: documents.length == 1 && c.userId != null
            ? ProfileDocumentSheet(
                key: ValueKey(
                  'booking-required-document-${documents.single.field.id}',
                ),
                owner: c.userId!,
                document: scopedDocument(documents.single, c.key),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ServiceDocumentRequirements(
                  requirements: c.requirements,
                  bookingKey: c.key,
                  busy: c.busy,
                  eligible: c.allowed,
                  error: c.error,
                  onRefresh: () => _refreshServiceDocuments(c),
                  onOpen: (r) async {
                    await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      backgroundColor: const Color(0xFFF8F9FE),
                      builder: (_) => ProfileDocumentSheet(
                        owner: c.userId!,
                        document: scopedDocument(r, c.key),
                      ),
                    );
                    if (mounted && c.alive) await _refreshServiceDocuments(c);
                  },
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(customerBookingProvider(widget.bookingKey));
    return Theme(
      data: CustomerTheme.authentication(),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => c.stage == BookingStage.loading && c.busy
            ? Scaffold(
                key: const ValueKey('booking-access-loading'),
                backgroundColor: CustomerColors.pageBackground,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    tooltip: 'Back to services',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/services'),
                  ),
                ),
                body: Semantics(
                  label: 'Checking service requirements',
                  liveRegion: true,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      for (final height in [116.0, 220.0])
                        Container(
                          height: height,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2F3),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : c.needsServiceDocuments
            ? _documentGate(c)
            : c.resendingRequest
            ? BookingRequestProgressView(
                matching: true,
                serviceName: c.context?.name ?? 'your service',
                busy: true,
                onCancel: null,
                onDetails: () {},
              )
            : c.stage == BookingStage.created &&
                  c.created?['requestId'] is int &&
                  {
                    'AWAITING_CUSTOMER_CONFIRMATION',
                    'PAYMENT_PENDING',
                    'PAYMENT_RECONCILIATION',
                  }.contains(c.created?['status'])
            ? CustomerRequestPaymentScreen(
                serviceName: c.context?.name,
                provider: [
                  ...c.candidates,
                  ...c.availableCandidates,
                  ...c.selected.values,
                ].where((p) => p.id == c.created?['providerId']).firstOrNull,
                key: ValueKey('request-payment-${c.created!['requestId']}'),
                requestId: c.created!['requestId'] as int,
                initialRequest: c.created,
              )
            : (c.stage == BookingStage.created && c.paymentOutcome != null) ||
                  (_replacementMethod != null &&
                      c.created == null &&
                      c.stage == BookingStage.review &&
                      !c.uncertain)
            ? PopScope(
                canPop: !c.busy,
                child: BookingPaymentResultScreen(
                  success: c.paymentOutcome == 'SUCCESS',
                  busy: c.busy,
                  selectedMethod: _replacementMethod,
                  selectedCardLabel: _replacementMethod == 'CARD'
                      ? _selectedCardSummary
                      : null,
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
                      (_replacementMethod != null ? c.error : null) ??
                      c.paymentFailureReason ??
                      (c.payment?['status'] == 'FAILED'
                          ? 'The test payment was not completed.'
                          : c.error),
                  onRetry: () async {
                    if (_replacementMethod != null) {
                      await _retryWithReplacementMethod(c);
                    } else {
                      if (c.created?['requestId'] is int &&
                          c.created?['paymentMethod'] == 'CARD') {
                        await _confirmAcceptedPayment(c);
                      } else {
                        await c.pay();
                      }
                    }
                    if (mounted) ref.invalidate(customerWalletProvider);
                  },
                  onDifferentMethod: !c.canChangePaymentMethod
                      ? null
                      : () async {
                          await _chooseReplacementPaymentMethod(c);
                        },
                  onBooking: () => _openCompletedBooking(c),
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
                onDetails: () async {
                  if (c.created?['paymentMethod'] == 'CARD') {
                    await _confirmAcceptedPayment(c);
                    return;
                  }
                  final amount = c.created?['expectedAmount'];
                  if (c.created?['paymentMethod'] == 'WALLET' &&
                      amount is num &&
                      amount.isFinite &&
                      c.created?['currencyCode'] is String) {
                    await c.confirmRequestWallet();
                    if (mounted) ref.invalidate(customerWalletProvider);
                  } else {
                    setState(() => _showRequestProgress = false);
                  }
                },
                onCancel: !c.canCancelCreatedRequest
                    ? null
                    : () async {
                        final cancel = await showDialog<bool>(
                          context: context,
                          builder: (_) => const BookingCancelRequestDialog(),
                        );
                        if (cancel == true && mounted) {
                          await c.cancelCreatedRequest();
                        }
                      },
              )
            : c.stage == BookingStage.created &&
                  c.created?['requestId'] is int &&
                  !c.uncertain
            ? BookingPaymentPage(
                onBack: c.busy ? null : () => _back(c),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c.error != null) _Notice(c.error!),
                    ..._created(c),
                  ],
                ),
              )
            : PopScope(
                canPop:
                    !c.busy &&
                    !(c.context?.route == true &&
                        c.stage == BookingStage.details &&
                        _rideLocationStep > 0) &&
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
                  backgroundColor: Colors.white,
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
                          backgroundColor: Colors.white,
                          foregroundColor: CustomerColors.text,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          surfaceTintColor: Colors.transparent,
                          systemOverlayStyle: SystemUiOverlayStyle.dark,
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
                          initialLocation: _initialLocation,
                          keyboardOpen:
                              MediaQuery.viewInsetsOf(context).bottom > 0,
                          controller: c,
                          onBack: () => _back(c),
                          onOptionChanged: (option) =>
                              _changeService(c, option),
                          panelTitle: c.stage == BookingStage.review
                              ? 'Review your booking'
                              : c.context!.route &&
                                    c.stage == BookingStage.serviceDetails
                              ? 'Passenger details'
                              : c.context!.route
                              ? (_rideLocationStep == 0
                                    ? 'Choose your route'
                                    : 'Vehicle and pickup time')
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
                                          Text(
                                            'Check your booking history',
                                            style: CustomerTypography.screen
                                                .copyWith(color: catalogInk),
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
                                            style: CustomerTypography.screen
                                                .copyWith(color: catalogInk),
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
                                            style: CustomerTypography.body
                                                .copyWith(color: catalogMuted),
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
        for (final reason in (c.access?['reasons'] as List? ?? []))
          _Notice('${(reason as Map)['message']}'),
        if (c.requirements.isEmpty)
          TextButton(
            onPressed: c.busy ? null : c.refreshRequirements,
            child: const Text('Refresh access'),
          ),
      ],
      if (!requirementsOnly) ...[
        if (!ctx.route && c.mode == 'PROVIDER_TO_CUSTOMER')
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
        if (ctx.route) ...[
          _rideStepHeader(2),
          ExpansionTile(
            key: const ValueKey('ride-route-recap'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              '${bookingShortAddress(c.address)} → ${bookingShortAddress(c.destinationAddress)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CustomerTypography.card,
            ),
            subtitle: const Text(
              'Trip locations',
              style: CustomerTypography.micro,
            ),
            children: [
              BookingRideDetails(
                controller: c,
                showPricing: false,
                onPickup: () => _chooseLocation(c),
                onDestination: () => _chooseLocation(c, destination: true),
              ),
            ],
          ),
          if (ctx.pricingFieldIds.any((id) => c.pricingSelections[id] == null))
            BookingRideDetails(
              controller: c,
              showTrip: false,
              onPickup: () => _chooseLocation(c),
              onDestination: () => _chooseLocation(c, destination: true),
            ),
          for (final name in ['Service address', 'Destination address'])
            if (c.fieldErrors[name] case final String error)
              Text(
                error,
                style: CustomerTypography.compact.copyWith(
                  color: CustomerColors.error,
                ),
              ),
        ],
        BookingServiceFields(controller: c),
        BookingServiceSchedule(
          controller: c,
          onEdit: c.busy
              ? null
              : () {
                  if (ctx.route) _rideLocationStep = 1;
                  c.details();
                },
        ),
        if (!requirementsOnly && !ctx.route)
          BookingPricingChoices(controller: c),
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
      for (final entry in {
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
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(
          'Choose a payment method',
          style: CustomerTypography.card.copyWith(color: catalogInk),
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
                : payment == 'WALLET'
                ? SvgPicture.asset(
                    'assets/icons/navigation/wallet_selected.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      catalogTeal,
                      BlendMode.srcIn,
                    ),
                    semanticsLabel: 'BThere Wallet',
                  )
                : const Icon(
                    Icons.payments_outlined,
                    color: catalogTeal,
                    size: 20,
                  ),
            title: Text(switch (payment) {
              'CARD' => 'Credit / Debit Card',
              'WALLET' => 'BThere Wallet',
              'CASH' => 'Cash on Hand',
              _ => payment,
            }, style: CustomerTypography.compactStrong),
            subtitle: Text(switch (payment) {
              'CARD' =>
                c.usesRequestPolicy
                    ? 'Pay after provider acceptance'
                    : 'Use your saved test card',
              'WALLET' => 'Use your available wallet balance',
              'CASH' => 'Pay the provider after the service',
              _ => '',
            }, style: CustomerTypography.micro),
            value: payment,
            enabled: !c.busy,
          ),
        ),
      ),
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
                      Text(
                        'Estimated total',
                        style: CustomerTypography.compact.copyWith(
                          color: catalogMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        c.quote == null
                            ? 'Preview price to see total'
                            : c.quote!['currencyCode'] == 'LKR'
                            ? walletMoney(c.quote!['expectedAmount'])
                            : '${c.quote!['currencyCode']} ${c.quote!['expectedAmount']}',
                        style:
                            (c.quote == null
                                    ? CustomerTypography.compact
                                    : CustomerTypography.section)
                                .copyWith(color: catalogInk),
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
                textStyle: CustomerTypography.compactStrong,
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

  Future<void> _chooseReplacementPaymentMethod(
    CustomerBookingController c,
  ) async {
    if (c.busy || !c.canChangePaymentMethod) return;
    final request = c.created;
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a payment method',
                style: CustomerTypography.screen.copyWith(color: catalogInk),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose another method, then tap Try Again to send a new provider request. Your booking details are kept.',
                style: CustomerTypography.compact.copyWith(color: catalogMuted),
              ),
              const SizedBox(height: 16),
              for (final method in c.availableMethods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: ValueKey('replacement-payment-$method'),
                    enabled: method != request?['paymentMethod'],
                    tileColor: const Color(0xFFF0FAFA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Icon(
                      method == 'CARD'
                          ? Icons.credit_card_rounded
                          : method == 'WALLET'
                          ? Icons.account_balance_wallet_outlined
                          : Icons.payments_outlined,
                      color: method == request?['paymentMethod']
                          ? catalogMuted
                          : catalogTeal,
                    ),
                    title: Text(
                      method == 'CARD'
                          ? 'Credit / Debit Card'
                          : method == 'WALLET'
                          ? 'BThere Wallet'
                          : 'Cash on Hand',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: catalogInk,
                      ),
                    ),
                    trailing: Icon(
                      method == request?['paymentMethod']
                          ? Icons.check_circle_outline
                          : Icons.chevron_right,
                      color: method == request?['paymentMethod']
                          ? catalogMuted
                          : catalogTeal,
                    ),
                    subtitle: method == request?['paymentMethod']
                        ? const Text('Current payment method')
                        : null,
                    onTap: method == request?['paymentMethod']
                        ? null
                        : () => Navigator.pop(sheetContext, method),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || !c.alive || method == null) return;
    if (method == 'CARD' && !await _selectPaymentCard(c)) {
      return;
    }
    if (!mounted ||
        !c.alive ||
        c.busy ||
        !identical(c.created, request) ||
        !c.canChangePaymentMethod) {
      return;
    }
    setState(() => _replacementMethod = method);
  }

  Future<void> _retryWithReplacementMethod(CustomerBookingController c) async {
    final method = _replacementMethod;
    if (method == null ||
        c.busy ||
        c.uncertain ||
        !c.availableMethods.contains(method)) {
      return;
    }
    if (c.created != null) {
      await c.changeRequestPaymentMethod();
      if (!mounted || !c.alive || c.created != null) return;
    }
    c.method = method;
    _showRequestProgress = true;
    _paymentConfirmation = false;
    await c.submit();
    if (mounted &&
        c.alive &&
        (c.created != null || c.stage != BookingStage.review || c.uncertain)) {
      setState(() => _replacementMethod = null);
    }
  }

  bool _openingCheckout = false;
  Future<void> _confirmAcceptedPayment(CustomerBookingController c) async {
    if (_openingCheckout || c.busy || !c.alive) return;
    _openingCheckout = true;
    try {
      final card = _selectedPaymentCard;
      final brand =
          '${card?['brand'] ?? card?['cardBrand'] ?? card?['displayLabel'] ?? ''}'
              .toUpperCase();
      String? method = brand.contains('MASTER')
          ? 'MASTER'
          : brand.contains('VISA') || brand.contains('TEST CARD')
          ? 'VISA'
          : null;
      method ??= await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Choose your card type',
                  style: CustomerTypography.screen,
                ),
              ),
              for (final entry in {
                'VISA': 'Visa',
                'MASTER': 'Mastercard',
              }.entries)
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: Text(entry.value),
                  onTap: () => Navigator.pop(sheetContext, entry.key),
                ),
            ],
          ),
        ),
      );
      if (!mounted || !c.alive || method == null) return;
      var email = c.auth.user?.email ?? '';
      var phone = c.auth.user?.phoneNumber ?? '';
      if (email.trim().isEmpty || phone.trim().isEmpty) {
        final contact = await showDialog<(String, String)>(
          context: context,
          builder: (_) =>
              BookingBillingContactDialog(email: email, phone: phone),
        );
        if (!mounted || !c.alive || contact == null) return;
        email = contact.$1;
        phone = contact.$2;
      }
      final checkout = await c.confirmRequestCard(
        method,
        billingEmail: email,
        billingPhone: phone,
      );
      if (!mounted || !c.alive) return;
      if (checkout == null) {
        if (c.paymentOutcome != 'SUCCESS') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                c.error ??
                    (c.busy
                        ? 'Request status is updating. Please try again in a moment.'
                        : 'Card checkout could not be started. Please check your request status.'),
              ),
            ),
          );
        }
        return;
      }
      await ref.read(bookingCardCheckoutPresenterProvider)(
        context,
        checkout,
        c,
      );
      if (mounted && c.alive) await c.refreshCreatedRequest();
    } catch (_) {
      if (mounted && c.alive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Secure checkout could not be opened. Checking your payment status.',
            ),
          ),
        );
        await c.refreshCreatedRequest();
      }
    } finally {
      _openingCheckout = false;
    }
  }

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

  List<Widget> _paymentConfirmationContents(CustomerBookingController c) =>
      bookingCheckoutContents(
        context: context,
        controller: c,
        cardLabel: _selectedPaymentCard?['displayLabel'] as String?,
        onMethodChanged: (value) async {
          if (c.busy) return;
          final previous = c.method;
          if (value == 'CARD' && !await _selectPaymentCard(c)) return;
          if (!mounted || !c.alive) return;
          c.method = value ?? previous;
          c.review();
        },
        onConfirm: () => _confirmBookingAndPay(c),
      );

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
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Providers must meet every selected language and skill.',
          style: CustomerTypography.compact.copyWith(color: catalogMuted),
        ),
      ),
    ],
  );

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
          backgroundColor: const Color(0xFFF7FBFB),
          side: const BorderSide(color: Color(0xFFDCE9EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    style: CustomerTypography.compact.copyWith(
                      color: catalogMuted,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CustomerTypography.card.copyWith(color: catalogInk),
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
      return location;
    },
  );

  Widget _rideStepHeader(int step) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var index = 0; index < 3; index++)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(right: 4, bottom: 10),
                  decoration: BoxDecoration(
                    color: index <= step
                        ? CustomerColors.action
                        : CustomerColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        Text(
          [
            'Where are you going?',
            'Vehicle and pickup time',
            'Passenger details',
          ][step],
          style: CustomerTypography.section,
        ),
        const SizedBox(height: 4),
        Text(
          'Step ${step + 1} of 3',
          style: CustomerTypography.micro.copyWith(
            color: CustomerColors.secondaryText,
          ),
        ),
      ],
    ),
  );

  void _continueRideLocations(CustomerBookingController c) {
    if (c.busy) return;
    setState(() {
      c.error = null;
      c.fieldErrors = {};
      if (c.point?.valid != true || c.address.trim().isEmpty) {
        c.fieldErrors['Location'] = 'Choose your pickup location.';
      }
      if (c.destination?.valid != true || c.destinationAddress.trim().isEmpty) {
        c.fieldErrors['Destination'] = 'Choose your destination.';
      }
      if (c.fieldErrors.isEmpty) _rideLocationStep = 1;
    });
  }

  List<Widget> _mapDetails(CustomerBookingController c) =>
      c.context!.route && _rideLocationStep == 0
      ? [
          _rideStepHeader(0),
          BookingRideDetails(
            controller: c,
            showPricing: false,
            onPickup: () => _chooseLocation(c),
            onDestination: () => _chooseLocation(c, destination: true),
          ),
          for (final name in ['Location', 'Destination'])
            if (c.fieldErrors[name] case final String error)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error,
                  style: CustomerTypography.compact.copyWith(
                    color: CustomerColors.error,
                  ),
                ),
              ),
          BThereButton(
            key: const ValueKey('ride-locations-continue'),
            label: 'Choose vehicle and time',
            onPressed: c.busy ? null : () => _continueRideLocations(c),
          ),
        ]
      : [
          if (c.context!.route) _rideStepHeader(1),
          if (c.context!.providerFilters.isNotEmpty)
            BookingProviderFilters(controller: c, rideStyle: c.context!.route),
          if (c.mode != 'ONLINE' && !c.context!.route) ...[
            BookingValidationGroup(
              key: const ValueKey('booking-location-validation'),
              error: c.fieldErrors['Location'],
              child: _locationRadius(c),
            ),
            const SizedBox(height: 8),
          ],
          BookingValidationGroup(
            key: const ValueKey('booking-schedule-validation'),
            error: c.fieldErrors['Duration'] ?? c.fieldErrors['Schedule'],
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
                filterStyle: true,
                choices: const [
                  {'value': 'SINHALA', 'label': 'Sinhala'},
                  {'value': 'ENGLISH', 'label': 'English'},
                  {'value': 'TAMIL', 'label': 'Tamil'},
                ],
                selected: c.languages,
                enabled: !c.busy,
                onChanged: (value, on) => c.edit(() {
                  if (on) {
                    c.languages
                      ..clear()
                      ..add(value);
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
      return [
        BookingRequestReceipt(
          request: b,
          busy: c.busy,
          onConfirmWallet: () async {
            if (b['paymentMethod'] == 'CARD') {
              await _confirmAcceptedPayment(c);
            } else {
              await c.confirmRequestWallet();
            }
            if (mounted) ref.invalidate(customerWalletProvider);
          },
          onRefresh: b['status'] == 'PAYMENT_PENDING'
              ? () => c.refreshCreatedRequest(background: true)
              : c.refreshCreatedRequest,
          onBookingForm: c.returnToBookingForm,
          onBookingFilters: c.returnToBookingFilters,
          onSendAgain: c.usesRequestPolicy
              ? () {
                  setState(() => _showRequestProgress = true);
                  c.resendExpiredRequest();
                }
              : null,
          onBookingDetails: b['jobId'] is int && (b['jobId'] as int) > 0
              ? () => _openCompletedBooking(c)
              : null,
          onHome: () => context.go('/home'),
        ),
      ];
    }
    return [
      const Icon(Icons.task_alt, color: catalogTeal, size: 68),
      const SizedBox(height: 16),
      Text(
        'Booking #${b['jobId']}',
        style: CustomerTypography.screen.copyWith(color: catalogInk),
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
      style: CustomerTypography.body.copyWith(color: catalogInk),
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

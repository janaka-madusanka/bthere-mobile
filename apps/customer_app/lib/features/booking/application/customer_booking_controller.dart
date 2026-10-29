import 'package:timezone/timezone.dart' as tz;

import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_providers.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../../discovery/domain/customer_discovery.dart';
import '../data/customer_booking_repository.dart';
import '../domain/booking_models.dart';

final customerBookingRepositoryProvider = Provider<CustomerBookingRepository>(
  (ref) => CustomerBookingRepository(ref.watch(customerAuthServiceProvider)),
  dependencies: [customerAuthServiceProvider],
);
final customerAutoAvailabilityEnabledProvider = Provider<bool>((ref) => true);
final customerBookingProvider = Provider.autoDispose
    .family<CustomerBookingController, BookingKey>(
      (ref, key) {
        final controller = CustomerBookingController(
          key,
          ref.watch(customerBookingRepositoryProvider),
          ref.watch(customerAuthControllerProvider),
          ref.watch(customerDiscoveryProvider),
          now: ref.watch(customerClockProvider),
          autoAvailability: ref.watch(customerAutoAvailabilityEnabledProvider),
        );
        ref.onDispose(controller.dispose);
        return controller;
      },
      dependencies: [
        customerBookingRepositoryProvider,
        customerAuthControllerProvider,
        customerDiscoveryProvider,
        customerClockProvider,
        customerAutoAvailabilityEnabledProvider,
      ],
    );

enum BookingStage {
  loading,
  details,
  serviceDetails,
  results,
  review,
  created,
  invalid,
}

class CustomerBookingController extends ChangeNotifier {
  CustomerBookingController(
    this.key,
    this.repository,
    this.auth,
    this.discovery, {
    required this.now,
    this.autoAvailability = true,
    this.availabilityDebounce = const Duration(milliseconds: 500),
  }) : userId = auth.user?.id {
    auth.addListener(_sync);
    discovery.addListener(_sync);
  }
  final BookingKey key;
  final CustomerBookingRepository repository;
  final CustomerAuthController auth;
  final CustomerDiscoveryController discovery;
  final DateTime Function() now;
  final bool autoAvailability;
  final Duration availabilityDebounce;
  Timer? _availabilityTimer;
  int _availabilityRevision = 0;
  bool checkingAvailability = false;
  String? availabilityError;
  String? availabilityNotice;
  String? get availabilityStatusLabel => context != null && !allowed
      ? 'Additional details needed'
      : checkingAvailability
      ? 'Checking providers…'
      : availabilityError ?? availabilityLabel;

  String? _availabilityFingerprint() {
    try {
      return jsonEncode(searchInput(locationStep: true));
    } catch (_) {
      return null;
    }
  }

  void _cancelAutoAvailability() {
    availabilityNotice = null;
    _availabilityTimer?.cancel();
    _availabilityTimer = null;
    _availabilityRevision++;
    checkingAvailability = false;
    availabilityError = null;
  }

  void _scheduleAutoAvailability() {
    _cancelAutoAvailability();
    if (!autoAvailability || !alive || busy || stage != BookingStage.details) {
      return;
    }
    if (!allowed || dirtyRequirements.isNotEmpty) return;
    final fingerprint = _availabilityFingerprint();
    if (fingerprint == null || fingerprint == _availabilityInput) return;
    final revision = _availabilityRevision;
    checkingAvailability = true;
    _availabilityTimer = Timer(
      availabilityDebounce,
      () => _fetchAutoAvailability(fingerprint, revision),
    );
  }

  Future<void> _fetchAutoAvailability(String fingerprint, int revision) async {
    bool current() =>
        alive &&
        !busy &&
        stage == BookingStage.details &&
        revision == _availabilityRevision &&
        fingerprint == _availabilityFingerprint();
    if (!current()) return;
    try {
      final result = await repository.search(searchInput(locationStep: true));
      if (!current()) return;
      if (result['requiredProviderCount'] != context!.providerCount ||
          result['timezone'] != context!.zone ||
          result['status'] == 'AVAILABLE' &&
              (result['candidates'] as List).isEmpty) {
        throw const FormatException('Invalid availability response');
      }
      _availability = result;
      _availabilityInput = fingerprint;
      _availableCandidates
        ..clear()
        ..addAll((result['candidates'] as List).map(ProviderCandidate.parse));
      availabilityError = null;
    } catch (failure) {
      if (current() && failure is BookingProblem && failure.eligibility) {
        try {
          final values = await Future.wait<Object>([
            repository.requirements(key),
            repository.eligibility(key),
          ]);
          if (!current()) return;
          requirements = values[0] as List<CustomerRequirement>;
          access = values[1] as Map<String, dynamic>;
          for (final r in requirements) {
            if (!dirtyRequirements.contains(r.field.id)) {
              requirementAnswers[r.field.id] = r.value;
              expiry[r.field.id] = r.expires;
            }
          }
        } catch (_) {
          // Keep a retryable failure if requirement discovery is unavailable.
        }
      }
      if (current()) {
        availabilityError = failure is BookingProblem && failure.eligibility
            ? 'Complete requirements to check providers'
            : 'Availability unavailable. Try again.';
      }
    } finally {
      if (current()) {
        checkingAvailability = false;
        _notify();
      }
    }
  }

  void retryAvailability() {
    _availabilityInput = null;
    _scheduleAutoAvailability();
    _notify();
  }

  final int? userId;
  BookingStage stage = BookingStage.loading;
  BookingContext? context;
  List<CustomerRequirement> requirements = [];
  Map<String, dynamic>? access;
  final answers = <String, Object?>{}, requirementAnswers = <int, Object?>{};
  final providerFilters = <int, Object?>{};
  final pricingSelections = <int, String>{};
  final expiry = <int, String?>{};
  final dirtyRequirements = <int>{};
  final languages = <String>{}, skills = <int>{};
  final candidates = <ProviderCandidate>[];
  final selected = <int, ProviderCandidate>{};
  Map<String, dynamic>? searchResult, created, payment;
  Map<String, dynamic> requestPolicy = const {'enabled': false};
  bool get isOpenRequest => context?.openRequest == true;
  bool get usesRequestPolicy => requestPolicy['enabled'] == true;
  Map<String, dynamic>? _availability;
  String? _availabilityInput;
  final _availableCandidates = <ProviderCandidate>[];
  Map<String, dynamic>? get availability {
    try {
      return _availabilityInput == jsonEncode(searchInput(locationStep: true))
          ? _availability
          : null;
    } catch (_) {
      return null;
    }
  }

  List<ProviderCandidate> get availableCandidates =>
      availability == null ? const [] : List.unmodifiable(_availableCandidates);
  bool get hasMoreAvailableProviders => availability?['hasNext'] == true;

  Future<void> loadMoreAvailableProviders() async {
    final snapshot = availability;
    if (busy || !alive || snapshot == null || snapshot['hasNext'] != true) {
      return;
    }
    _cancelAutoAvailability();
    final input = searchInput(
      locationStep: true,
      page: (snapshot['page'] as int) + 1,
    );
    final epoch = ++_epoch;
    busy = true;
    error = null;
    _notify();
    try {
      final result = await repository.search(input);
      if (!alive || epoch != _epoch) return;
      if (result['status'] != 'AVAILABLE' ||
          result['requiredProviderCount'] != context!.providerCount ||
          result['timezone'] != context!.zone) {
        throw const BookingProblem(
          'Availability changed. Please apply the filters again.',
        );
      }
      final known = _availableCandidates
          .map((candidate) => candidate.key)
          .toSet();
      for (final row in result['candidates'] as List) {
        final candidate = ProviderCandidate.parse(row);
        if (known.add(candidate.key)) _availableCandidates.add(candidate);
      }
      _availability = result;
    } catch (failure) {
      if (alive && epoch == _epoch) await _failure(failure);
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  String? get availabilityLabel {
    final result = availability;
    if (result == null) return null;
    if (result['status'] == 'NO_AVAILABLE_PROVIDERS') {
      return (result['totalCandidates'] as int) > 0
          ? 'Not enough providers available'
          : 'No providers available';
    }
    final count = _availableCandidates
        .map((candidate) => candidate.id)
        .toSet()
        .length;
    return '$count${result['hasNext'] == true ? '+' : ''} ${count == 1 && result['hasNext'] != true ? 'provider' : 'providers'} available';
  }

  String? paymentFailureReason;
  bool _paymentAttemptUncertain = false, _showPaymentResult = true;
  bool get canChangePaymentMethod =>
      created?['requestId'] is int &&
      created?['status'] == 'AWAITING_CUSTOMER_CONFIRMATION' &&
      availableMethods.any((m) => m != created?['paymentMethod']) &&
      {'NOT_STARTED', 'PENDING'}.contains(created?['paymentStatus']);
  bool get canCancelCreatedRequest =>
      created?['requestId'] is int &&
      {
        'MATCHING',
        'AWAITING_CUSTOMER_CONFIRMATION',
      }.contains(created?['status']) &&
      {'NOT_STARTED', 'PENDING'}.contains(created?['paymentStatus']);
  Future<void> cancelCreatedRequest() async {
    if (!alive || busy || !canCancelCreatedRequest) return;
    final epoch = _epoch;
    busy = true;
    error = null;
    _notify();
    try {
      final result = await repository.cancelRequest(
        created!['requestId'] as int,
      );
      if (alive && epoch == _epoch) created = {...created!, ...result};
    } catch (failure) {
      if (alive && epoch == _epoch) await _failure(failure);
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  String? get paymentOutcome {
    if (!_showPaymentResult || _paymentAttemptUncertain || created == null) {
      return null;
    }
    final status = created!['paymentStatus'];
    if (created!['requestId'] is int) {
      if ({
            'CONFIRMED',
            'IN_PROGRESS',
            'AWAITING_COMPLETION_CONFIRMATION',
            'COMPLETED',
          }.contains(created!['status']) &&
          {'PAID', 'RESERVED', 'SETTLED'}.contains(status)) {
        return 'SUCCESS';
      }
    } else if ((created!['paymentMethod'] == 'CARD' &&
            payment?['status'] == 'SUCCEEDED') ||
        (created!['paymentMethod'] == 'WALLET' &&
            {'RESERVED', 'SETTLED'}.contains(status) &&
            payment?['status'] == 'POSTED')) {
      return 'SUCCESS';
    }
    if (status == 'FAILED' ||
        payment?['status'] == 'FAILED' ||
        paymentFailureReason != null) {
      return 'FAILURE';
    }
    return null;
  }

  void dismissPaymentResult() {
    _showPaymentResult = false;
    _notify();
  }

  void _startPaymentPresentation() {
    paymentFailureReason = null;
    _paymentAttemptUncertain = false;
    _showPaymentResult = true;
  }

  void _paymentFailure(Object failure) {
    _paymentAttemptUncertain =
        failure is NetworkException ||
        failure is FormatException ||
        failure is BookingProblem && (failure.status ?? 0) >= 500;
    if (failure is BookingProblem &&
        {402, 409}.contains(failure.status) &&
        RegExp(
          r'insufficient|declin|balance',
          caseSensitive: false,
        ).hasMatch(failure.message)) {
      paymentFailureReason = failure.message;
    }
  }

  Future<void> changeRequestPaymentMethod() async {
    if (!alive || busy || !canChangePaymentMethod) return;
    final epoch = _epoch;
    final id = created!['requestId'] as int;
    busy = true;
    error = null;
    _notify();
    try {
      await repository.cancelRequest(id);
      if (!alive || epoch != _epoch) return;
      created = payment = null;
      method = null;
      _startPaymentPresentation();
      stage = BookingStage.review;
    } catch (failure) {
      if (alive && epoch == _epoch) await _failure(failure);
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Map<String, dynamic>? _quote;
  String? _quotedInput;
  Map<String, dynamic>? get quote {
    try {
      return _quotedInput == jsonEncode(bookingInput()) ? _quote : null;
    } catch (_) {
      return null;
    }
  }

  void choosePricing(int id, String? value) {
    if (busy || !alive || created != null || uncertain) return;
    if (value == null) {
      pricingSelections.remove(id);
    } else {
      pricingSelections[id] = value;
    }
    _quote = null;
    _quotedInput = null;
    _notify();
  }

  Map<String, dynamic> capabilities = {};
  Map<String, String> fieldErrors = {};
  String? error, paymentError;
  String start = '', end = '', address = '', destinationAddress = '', note = '';
  String? mode, method;
  GeoPoint? point, destination;
  double radius = 5;
  bool busy = false, uncertain = false, hasNext = false, _disposed = false;
  int _epoch = 0, _page = 0;
  bool get allowed => access?['eligible'] == true;
  bool get alive =>
      !_disposed &&
      auth.stage == CustomerAuthStage.authenticated &&
      auth.user?.id == userId &&
      discovery.activeMarket?.id == key.marketId;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sync() {
    if (!alive) {
      _cancelAutoAvailability();
      _epoch++;
      context = null;
      _availability = null;
      _availabilityInput = null;
      _availableCandidates.clear();
      answers.clear();
      providerFilters.clear();
      pricingSelections.clear();
      requirementAnswers.clear();
      requirements = [];
      access = null;
      capabilities = {};
      expiry.clear();
      dirtyRequirements.clear();
      candidates.clear();
      selected.clear();
      created = payment = searchResult = _quote = null;
      _quotedInput = null;
      point = destination = null;
      start = end = address = destinationAddress = note = '';
      stage = BookingStage.invalid;
      busy = false;
      _notify();
    }
  }

  Future<void> _failure(Object failure) async {
    error = failure is BookingProblem
        ? failure.message
        : failure is CustomerAuthFailure
        ? failure.message
        : failure is FormatException
        ? 'The server returned an unsupported response. Please refresh or contact support.'
        : 'Unable to connect. Please try again.';
    fieldErrors = failure is BookingProblem ? failure.errors : {};
    if (failure is CustomerAuthFailure && failure.status == 401) {
      await auth.restore();
    }
  }

  Future<void> load() async {
    if (!alive || busy) return;
    _cancelAutoAvailability();
    _availability = null;
    _availabilityInput = null;
    _availableCandidates.clear();
    if (key.marketId <= 0 || key.serviceId <= 0 || key.optionId <= 0) {
      stage = BookingStage.invalid;
      error = 'Choose a valid service again.';
      _notify();
      return;
    }
    final epoch = ++_epoch;
    busy = true;
    error = null;
    _notify();
    try {
      final values = await Future.wait<Object?>([
        repository.context(key),
        repository.requirements(key),
        repository.eligibility(key),
        repository.requestPolicy(key.optionId),
      ]);
      if (!alive || epoch != _epoch) return;
      final next = values[0] as BookingContext;
      final previousFields = {
        for (final field in context?.fields ?? <BookingField>[])
          field.code: field,
      };
      context = next;
      providerFilters.clear();
      pricingSelections.clear();
      requirements = values[1] as List<CustomerRequirement>;
      access = values[2] as Map<String, dynamic>;
      requestPolicy = values[3] as Map<String, dynamic>;
      answers.removeWhere(
        (code, _) => !next.fields.any(
          (f) =>
              f.code == code &&
              f.id == previousFields[code]?.id &&
              f.version == previousFields[code]?.version &&
              f.type == previousFields[code]?.type,
        ),
      );
      for (final r in requirements) {
        if (!dirtyRequirements.contains(r.field.id)) {
          requirementAnswers[r.field.id] = r.value;
          expiry[r.field.id] = r.expires;
        }
      }
      if (!next.modes.contains(mode)) {
        mode = next.modes.contains('PROVIDER_TO_CUSTOMER')
            ? 'PROVIDER_TO_CUSTOMER'
            : next.modes.first;
      }
      try {
        final settings = await repository.capabilities();
        if (!alive || epoch != _epoch) return;
        capabilities = settings;
        paymentError = null;
      } catch (_) {
        if (!alive || epoch != _epoch) return;
        capabilities = {};
        paymentError = 'Payment options could not be loaded. Cash remains available only if configured.';
      }
      if (!alive || epoch != _epoch) return;
      if (!availableMethods.contains(method)) {
        method = availableMethods.length == 1 ? availableMethods.single : null;
      }
      if (start.isEmpty) {
        final local = tz.TZDateTime.from(
          now().add(
            Duration(
              minutes: usesRequestPolicy
                  ? requestPolicy['minimumNoticeMinutes'] as int
                  : 0,
            ),
          ),
          MarketTime.location(next.zone),
        );
        // The next quarter-hour is the closest valid current-time default:
        // the API requires a strictly future start, rather than a past slot.
        final initial = DateTime.utc(
          local.year,
          local.month,
          local.day,
          local.hour,
          ((local.minute ~/ 15) + 1) * 15,
        );
        start = MarketTime.local(initial);
        if (!next.route) {
          end = MarketTime.local(initial.add(const Duration(hours: 6)));
        }
      }
      stage = BookingStage.details;
      _resetSearch();
    } catch (e) {
      if (alive && epoch == _epoch) await _failure(e);
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _scheduleAutoAvailability();
        _notify();
      }
    }
  }

  List<String> get availableMethods =>
      context?.methods
          .where(
            (m) => usesRequestPolicy
                ? {'CARD', 'WALLET'}.contains(m)
                : isOpenRequest
                ? false
                : m == 'CASH' ||
                      m == 'WALLET' &&
                          capabilities['bookingReservations'] == true ||
                      m == 'CARD' && capabilities['cardCheckout'] == true,
          )
          .toList() ??
      [];

  /// Resume refreshes checkout settings without throwing away the user's draft.
  Future<void> refreshCheckoutOptions() async {
    if (!alive || busy || uncertain || created != null || context == null) {
      return;
    }
    final epoch = _epoch;
    try {
      final values = await Future.wait([
        repository.requestPolicy(key.optionId),
        repository.capabilities(),
      ]);
      if (!alive || epoch != _epoch || busy || uncertain || created != null) {
        return;
      }
      requestPolicy = values[0];
      capabilities = values[1];
      paymentError = null;
      if (!availableMethods.contains(method)) {
        method = availableMethods.length == 1 ? availableMethods.single : null;
      }
    } catch (_) {
      if (!alive || epoch != _epoch || created != null) return;
      paymentError =
          'Payment options could not be refreshed. Please try again.';
    }
    _notify();
  }

  void _resetSearch() {
    _quote = null;
    _quotedInput = null;
    pricingSelections.clear();
    candidates.clear();
    selected.clear();
    searchResult = null;
    hasNext = false;
    _page = 0;
  }

  void edit(VoidCallback change) {
    if (busy || created != null || uncertain) return;
    final previousInput = _availabilityFingerprint();
    final revalidate = stage == BookingStage.details && fieldErrors.isNotEmpty;
    final revalidateService =
        stage == BookingStage.serviceDetails && fieldErrors.isNotEmpty;
    change();
    availabilityNotice = null;
    _epoch++;
    final matchingChanged = previousInput != _availabilityFingerprint();
    if (matchingChanged) {
      _resetSearch();
    } else {
      _quote = null;
      _quotedInput = null;
    }
    if (stage != BookingStage.serviceDetails || matchingChanged) {
      stage = BookingStage.details;
    }
    error = null;
    fieldErrors = {};
    if (revalidate) _validateLocationDetails();
    if (revalidateService && stage == BookingStage.serviceDetails) {
      _validateServiceDetails();
    }
    if (matchingChanged) {
      _scheduleAutoAvailability();
    }
    _notify();
  }

  void answer(BookingField field, Object? value) {
    edit(() {
      answers[field.code] = value;
      var changed = true;
      while (changed) {
        changed = false;
        for (final f in context!.fields) {
          if (!f.applies(answers) && answers.containsKey(f.code)) {
            answers.remove(f.code);
            changed = true;
          }
        }
      }
    });
  }

  void requirementAnswer(BookingField field, Object? value) {
    if (busy) return;
    requirementAnswers[field.id] = value;
    dirtyRequirements.add(field.id);
    _notify();
  }

  void openRequirements() {
    if (busy || !alive || created != null || uncertain) return;
    _cancelAutoAvailability();
    _availability = null;
    _availabilityInput = null;
    _availableCandidates.clear();
    error = null;
    fieldErrors = {};
    stage = BookingStage.serviceDetails;
    _notify();
  }

  Future<void> refreshRequirements() async {
    if (busy || !alive) return;
    final epoch = ++_epoch;
    busy = true;
    error = null;
    _notify();
    try {
      await _refreshEligibility(epoch);
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> saveRequirements() async {
    if (busy || !alive) return;
    final submissions = <Map<String, Object?>>[];
    try {
      for (final r in requirements) {
        if (!dirtyRequirements.contains(r.field.id)) continue;
        final value = requirementAnswers[r.field.id];
        final issue = r.field.validate(value, reusable: true);
        if (issue != null || value == null) {
          throw BookingProblem(
            '${r.field.label}: ${issue ?? 'Enter an answer'}',
          );
        }
        final date = expiry[r.field.id];
        if (date != null && date.isNotEmpty) {
          final parsed = DateTime.tryParse(date);
          if (parsed == null ||
              parsed.toIso8601String().substring(0, 10) != date ||
              parsed.isBefore(DateTime(now().year, now().month, now().day))) {
            throw const BookingProblem(
              'Choose a valid expiry date that is not in the past.',
            );
          }
        }
        submissions.add({
          'requirementId': r.field.id,
          'value': value,
          'expiresOn': date?.isEmpty == true ? null : date,
        });
      }
      if (submissions.isEmpty) return;
    } catch (e) {
      await _failure(e);
      _notify();
      return;
    }
    final epoch = ++_epoch;
    busy = true;
    error = null;
    _notify();
    try {
      await repository.saveRequirements(submissions);
      final rows = await repository.requirements(key);
      final eligibility = await repository.eligibility(key);
      if (!alive || epoch != _epoch) return;
      dirtyRequirements.clear();
      requirements = rows;
      access = eligibility;
      for (final r in rows) {
        requirementAnswers[r.field.id] = r.value;
        expiry[r.field.id] = r.expires;
      }
      _resetSearch();
    } catch (e) {
      if (alive && epoch == _epoch) await _failure(e);
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Map<String, Object?> searchInput({int page = 0, bool locationStep = false}) {
    final ctx = context;
    if (ctx == null ||
        !locationStep && (!allowed || dirtyRequirements.isNotEmpty)) {
      throw const BookingProblem(
        'Complete and save the customer requirements before searching.',
      );
    }
    if (!ctx.modes.contains(mode)) {
      throw const BookingProblem('Choose a supported delivery mode.');
    }
    if (!radius.isFinite || radius < .1 || radius > 500) {
      throw const BookingProblem('Choose a radius between 0.1 and 500 km.');
    }
    final from = MarketTime.parse(start, ctx.zone);
    if (!from.isAfter(now())) {
      throw const BookingProblem('Choose a future start time.');
    }
    if (usesRequestPolicy &&
        from.difference(now()) <
            Duration(minutes: requestPolicy['minimumNoticeMinutes'] as int)) {
      throw BookingProblem(
        'Choose a start time at least ${requestPolicy['minimumNoticeMinutes']} minutes from now.',
      );
    }
    if (usesRequestPolicy &&
        radius > (requestPolicy['maximumRadiusKm'] as num)) {
      throw BookingProblem(
        'Choose a radius up to ${requestPolicy['maximumRadiusKm']} km for this service.',
      );
    }
    if (!ctx.route) {
      MarketTime.interval(from, MarketTime.parse(end, ctx.zone), now());
    }
    if (ctx.route && mode != 'PROVIDER_TO_CUSTOMER') {
      throw const BookingProblem('This route configuration is unsupported.');
    }
    if (mode != 'ONLINE' && (point == null || !point!.valid)) {
      throw const BookingProblem('Choose a valid service location on the map.');
    }
    if (ctx.route && (destination == null || !destination!.valid)) {
      throw const BookingProblem('Choose a valid destination.');
    }
    if (!locationStep &&
        ctx.route &&
        (address.trim().isEmpty ||
            destinationAddress.trim().isEmpty ||
            address.length > 500 ||
            destinationAddress.length > 500)) {
      throw const BookingProblem(
        'Enter pickup and destination addresses, up to 500 characters each.',
      );
    }
    if (!locationStep &&
        !ctx.route &&
        mode == 'PROVIDER_TO_CUSTOMER' &&
        (address.trim().isEmpty || address.length > 255)) {
      throw const BookingProblem(
        'Enter the service address, up to 255 characters.',
      );
    }
    for (final f in locationStep ? <BookingField>[] : ctx.fields) {
      if (f.applies(answers)) {
        final issue = f.validate(answers[f.code]);
        if (issue != null) throw BookingProblem('${f.label}: $issue');
      }
    }
    if (!locationStep && note.length > 4000) {
      throw const BookingProblem('Use at most 4000 characters for the note.');
    }
    if (skills.any((id) => !ctx.skills.any((s) => s['skillId'] == id))) {
      throw const BookingProblem('Choose skills configured for this service.');
    }
    final filters = <Map<String, Object?>>[];
    if (providerFilters.keys.any(
      (id) => !ctx.providerFilters.any((f) => f.id == id),
    )) {
      throw const BookingProblem(
        'Provider preferences changed. Refresh the service.',
      );
    }
    for (final field in ctx.providerFilters) {
      final value = field.serialize(providerFilters[field.id]);
      if (value != null) filters.add(value);
    }
    if (filters.length > 50) {
      throw const BookingProblem('Choose at most 50 provider preferences.');
    }
    return {
      'marketId': key.marketId,
      'serviceTypeId': key.serviceId,
      'optionId': key.optionId,
      'deliveryMode': mode,
      'startAt': MarketTime.offset(from),
      if (!ctx.route)
        'endAt': MarketTime.offset(MarketTime.parse(end, ctx.zone)),
      if (!ctx.route && mode != 'ONLINE') 'location': point!.toJson(),
      if (ctx.route) 'pickup': point!.toJson(),
      if (ctx.route) 'destination': destination!.toJson(),
      if (mode != 'ONLINE') 'radiusKm': radius,
      'languages': languages.toList(),
      'requiredSkillIds': skills.toList(),
      if (filters.isNotEmpty) 'providerFilters': filters,
      'page': page,
      'pageSize': 20,
    };
  }

  void _validateServiceDetails() {
    fieldErrors = {};
    final ctx = context!;
    if (mode == 'PROVIDER_TO_CUSTOMER' &&
        (address.trim().isEmpty || address.length > (ctx.route ? 500 : 255))) {
      fieldErrors['Service address'] =
          'Choose the service address on the previous location step.';
    }
    if (ctx.route &&
        (destinationAddress.trim().isEmpty ||
            destinationAddress.length > 500)) {
      fieldErrors['Destination address'] = 'Enter the destination address.';
    }
    for (final field in ctx.fields) {
      if (!field.applies(answers)) continue;
      final issue = field.validate(answers[field.code]);
      if (issue != null) {
        fieldErrors['service-field-${field.id}'] = issue == 'Required'
            ? 'Complete this field.'
            : issue;
      }
    }
    if (note.length > 4000) {
      fieldErrors['Notes'] = 'Use at most 4000 characters.';
    }
  }

  Future<void> search({bool more = false}) async {
    if (busy || !alive || created != null || uncertain) return;
    _cancelAutoAvailability();
    if (!more && stage == BookingStage.serviceDetails) {
      _validateServiceDetails();
      if (fieldErrors.isNotEmpty) {
        error = 'Complete the highlighted details to continue.';
        _notify();
        return;
      }
    }
    Map<String, Object?> input;
    try {
      input = searchInput(page: more ? _page + 1 : 0, locationStep: more);
    } catch (e) {
      await _failure(e);
      _notify();
      return;
    }
    final epoch = ++_epoch;
    busy = true;
    error = null;
    fieldErrors = {};
    if (!more) _resetSearch();
    _notify();
    try {
      if (!more) {
        final fresh = await repository.context(
          key,
          pricingPoint: mode == 'ONLINE' ? null : point,
        );
        if (!alive || epoch != _epoch) return;
        context = fresh;
        input = searchInput();
      }
      final result = await repository.search(input);
      if (!alive || epoch != _epoch) return;
      if (result['requiredProviderCount'] != context!.providerCount ||
          result['timezone'] != context!.zone) {
        throw const BookingProblem(
          'Service configuration changed. Refresh the booking details.',
        );
      }
      final known = candidates.map((c) => c.key).toSet();
      for (final row in result['candidates'] as List) {
        final c = ProviderCandidate.parse(row);
        if (known.add(c.key)) candidates.add(c);
      }
      searchResult = result;
      _availability = result;
      _availabilityInput = jsonEncode(searchInput(locationStep: true));
      _availableCandidates
        ..clear()
        ..addAll(candidates);
      _page = input['page'] as int;
      hasNext = result['hasNext'] as bool;
      stage = BookingStage.results;
    } catch (e) {
      if (alive && epoch == _epoch) {
        await _failure(e);
        if (!alive || epoch != _epoch) return;
        if (e is BookingProblem && e.eligibility) {
          await _refreshEligibility(epoch);
          if (alive && epoch == _epoch) stage = BookingStage.details;
        }
      }
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  void select(ProviderCandidate candidate) {
    if (busy || !candidates.any((c) => c.key == candidate.key)) return;
    _quote = null;
    _quotedInput = null;
    if (selected[candidate.id]?.key == candidate.key) {
      selected.remove(candidate.id);
    } else if (context!.providerCount == 1) {
      selected.clear();
      selected[candidate.id] = candidate;
    } else if (selected.containsKey(candidate.id) ||
        selected.length < context!.providerCount) {
      selected[candidate.id] = candidate;
    }
    _notify();
  }

  void review() {
    _quote = null;
    _quotedInput = null;
    if (!isOpenRequest && selected.length != context?.providerCount) {
      error = 'Select ${context?.providerCount} distinct provider(s).';
    } else {
      stage = BookingStage.review;
      error = null;
    }
    _notify();
  }

  void details() {
    if (busy || created != null || uncertain) return;
    stage = BookingStage.details;
    _resetSearch();
    _scheduleAutoAvailability();
    _notify();
  }

  void continueWithProviders() {
    if (busy || !alive || created != null || uncertain) return;
    if (isOpenRequest ||
        selected.length != context?.providerCount ||
        searchResult?['status'] != 'AVAILABLE') {
      return;
    }
    error = null;
    fieldErrors = {};
    stage = BookingStage.serviceDetails;
    _notify();
  }

  void continueServiceDetails() {
    if (busy || !alive || created != null || uncertain) return;
    _validateServiceDetails();
    if (fieldErrors.isNotEmpty) {
      error = 'Complete the highlighted details to continue.';
      _notify();
      return;
    }
    try {
      searchInput();
      if (availability == null || searchResult?['status'] != 'AVAILABLE') {
        throw const BookingProblem(
          'Apply your filters again to check availability.',
        );
      }
      if (!isOpenRequest && selected.length != context!.providerCount) {
        throw const BookingProblem(
          'Choose the required providers before continuing.',
        );
      }
      review();
    } on BookingProblem catch (failure) {
      error = failure.message;
      _notify();
    }
  }

  void backFromServiceDetails() {
    if (!isOpenRequest && selected.isNotEmpty && searchResult != null) {
      backToResults();
    } else {
      details();
    }
  }

  void _validateLocationDetails() {
    fieldErrors = {};
    for (final field in context!.providerFilters) {
      try {
        if (field.serialize(providerFilters[field.id]) == null) {
          fieldErrors[field.label] = field.type == 'NUMBER'
              ? 'Enter a range to continue.'
              : field.type == 'BOOLEAN'
              ? 'Choose Yes or No to continue.'
              : 'Choose at least one option to continue.';
        }
      } on BookingProblem catch (problem) {
        fieldErrors[field.label] = problem.message;
      }
    }
    if (!context!.providerFilters.any(
          (field) => field.label.toLowerCase().contains('language'),
        ) &&
        languages.isEmpty) {
      fieldErrors['Language'] = 'Choose at least one language.';
    }
    if (context!.skills.isNotEmpty && skills.isEmpty) {
      fieldErrors['Skills'] = 'Choose at least one skill.';
    }
    if (mode != 'ONLINE' && (point == null || !point!.valid)) {
      fieldErrors['Location'] = 'Choose where you need the service.';
    }
    if (mode == 'PROVIDER_TO_CUSTOMER' &&
        point?.valid == true &&
        (address.trim().isEmpty ||
            address.length > (context!.route ? 500 : 255))) {
      fieldErrors['Location'] = 'Choose an address using location search.';
    }
    if (context!.route && (destination == null || !destination!.valid)) {
      fieldErrors['Destination'] = 'Choose the destination.';
    }
    if (start.trim().isEmpty) {
      fieldErrors['Start time'] = 'Choose a date and start time.';
    } else {
      try {
        final from = MarketTime.parse(start, context!.zone);
        if (!from.isAfter(now())) {
          fieldErrors['Start time'] = 'Choose a future start time.';
        }
        if (!context!.route && end.trim().isNotEmpty) {
          MarketTime.interval(
            from,
            MarketTime.parse(end, context!.zone),
            now(),
          );
        }
      } catch (e) {
        fieldErrors['Schedule'] = e is BookingProblem
            ? e.message
            : 'Choose a valid date, time and duration.';
      }
    }
    if (!context!.route && end.trim().isEmpty) {
      fieldErrors['Duration'] = 'Choose how long you need the service.';
    }
  }

  Future<void> nextServiceDetails() async {
    if (busy || !alive || created != null || uncertain) return;
    _cancelAutoAvailability();
    if (!allowed || dirtyRequirements.isNotEmpty) {
      openRequirements();
      return;
    }
    _validateLocationDetails();
    if (fieldErrors.isNotEmpty) {
      error = 'Complete the highlighted details to continue.';
      _notify();
      return;
    }

    final epoch = ++_epoch;
    busy = true;
    error = null;
    _notify();
    try {
      searchInput(locationStep: true);
      final fresh = await repository.context(
        key,
        pricingPoint: mode == 'ONLINE' ? null : point,
      );
      if (!alive || epoch != _epoch) return;
      final previous = {for (final field in context!.fields) field.code: field};
      context = fresh;
      answers.removeWhere(
        (code, _) => !fresh.fields.any(
          (field) =>
              field.code == code &&
              field.id == previous[code]?.id &&
              field.version == previous[code]?.version &&
              field.type == previous[code]?.type,
        ),
      );
      providerFilters.removeWhere((id, value) {
        final fields = fresh.providerFilters.where((field) => field.id == id);
        if (fields.isEmpty) return true;
        try {
          return fields.first.serialize(value) == null;
        } on BookingProblem {
          return true;
        }
      });
      skills.removeWhere(
        (id) => !fresh.skills.any((skill) => skill['skillId'] == id),
      );
      _resetSearch();
      _validateLocationDetails();
      if (fieldErrors.isNotEmpty) {
        error = 'Complete the highlighted details to continue.';
        return;
      }
      final input = searchInput(locationStep: true);
      _availability = null;
      _availabilityInput = null;
      _availableCandidates.clear();
      final result = await repository.search(input);
      if (!alive || epoch != _epoch) return;
      if (result['requiredProviderCount'] != fresh.providerCount ||
          result['timezone'] != fresh.zone ||
          result['providerSelectionMode'] !=
              fresh.option['providerSelectionMode']) {
        throw const BookingProblem(
          'Service availability changed. Please try again.',
        );
      }
      final matches = (result['candidates'] as List)
          .map(ProviderCandidate.parse)
          .toList();
      if (result['status'] == 'AVAILABLE' && matches.isEmpty) {
        throw const BookingProblem(
          'Availability could not be confirmed. Please try again.',
        );
      }
      _availabilityInput = jsonEncode(input);
      _availability = result;
      _availableCandidates.addAll(matches);
      if (result['status'] == 'NO_AVAILABLE_PROVIDERS') {
        error = null;
        availabilityNotice = (result['totalCandidates'] as int) > 0
            ? 'More providers are needed for this booking'
            : 'No matching providers just yet';
        stage = BookingStage.details;
        return;
      }
      error = null;
      availabilityNotice = null;
      searchResult = result;
      candidates.addAll(matches);
      hasNext = result['hasNext'] as bool;
      _page = 0;
      stage = isOpenRequest
          ? BookingStage.serviceDetails
          : BookingStage.results;
    } catch (e) {
      if (!alive || epoch != _epoch) return;
      error = e is BookingProblem
          ? e.message
          : 'Unable to refresh the booking form. Please try again.';
      if (e is BookingProblem && e.eligibility) {
        await _refreshEligibility(epoch);
        if (alive && epoch == _epoch) stage = BookingStage.serviceDetails;
      }
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  void backToServiceDetails() {
    if (busy || created != null || uncertain) return;
    stage = BookingStage.serviceDetails;
    error = null;
    _notify();
  }

  void backToResults() {
    if (busy || created != null || uncertain || searchResult == null) return;
    stage = BookingStage.results;
    error = null;
    _notify();
  }

  Map<String, Object?> openEstimateInput() {
    final ctx = context!;
    searchInput(locationStep: true);
    if (!isOpenRequest) {
      throw const BookingProblem('Choose an open request service.');
    }
    if (mode == 'CUSTOMER_TO_PROVIDER') {
      throw const BookingProblem(
        'A price estimate for this service location is not available yet.',
      );
    }
    for (final id in ctx.pricingFieldIds) {
      final field = ctx.providerFilters.singleWhere((f) => f.id == id);
      if (!field.options.any((o) => o['value'] == pricingSelections[id])) {
        throw BookingProblem('Choose ${field.label} to see an estimate.');
      }
    }
    return {
      'marketId': key.marketId,
      'booking': {
        'serviceTypeId': key.serviceId,
        'optionId': key.optionId,
        'deliveryMode': mode,
        if (!ctx.route)
          'startDatetime': MarketTime.local(MarketTime.parse(start, ctx.zone)),
        if (!ctx.route)
          'expectedEndDatetime': MarketTime.local(
            MarketTime.parse(end, ctx.zone),
          ),
        if (ctx.route)
          'requestedPickupTime': MarketTime.local(
            MarketTime.parse(start, ctx.zone),
          ),
        if (ctx.route)
          'pickup': {...point!.toJson(), 'address': address.trim()},
        if (ctx.route)
          'destination': {
            ...destination!.toJson(),
            'address': destinationAddress.trim(),
          },
        if (!ctx.route && mode == 'PROVIDER_TO_CUSTOMER')
          'meetingPoint': {
            'name': 'Service location',
            'addressLine1': address.trim(),
            ...point!.toJson(),
          },
        'pricingSelections': [
          for (final id in ctx.pricingFieldIds)
            {'fieldId': id, 'choiceValue': pricingSelections[id]},
        ],
      },
    };
  }

  Map<String, Object?> bookingInput({String? quotePaymentMethod}) {
    final ctx = context!;
    searchInput();
    if ((!isOpenRequest && selected.length != ctx.providerCount) ||
        searchResult == null) {
      throw const BookingProblem(
        'Search again and select the required providers.',
      );
    }
    final paymentMethod = quotePaymentMethod ?? method;
    if (!availableMethods.contains(paymentMethod)) {
      throw const BookingProblem('Choose an available payment method.');
    }
    if (pricingSelections.keys.any((id) => !ctx.pricingFieldIds.contains(id))) {
      throw const BookingProblem('Refresh the pricing choices.');
    }
    for (final id in ctx.pricingFieldIds) {
      final field = ctx.providerFilters.singleWhere((f) => f.id == id);
      if (!field.options.any((o) => o['value'] == pricingSelections[id])) {
        throw BookingProblem('Choose ${field.label} for pricing.');
      }
    }
    final first = selected.values.firstOrNull;
    if (!isOpenRequest &&
        mode == 'CUSTOMER_TO_PROVIDER' &&
        first?.locationId == null) {
      throw const BookingProblem('Choose a public provider location.');
    }
    return {
      'serviceTypeId': key.serviceId,
      'optionId': key.optionId,
      if (!isOpenRequest && ctx.providerCount == 1) 'providerId': first!.id,
      if (!isOpenRequest && ctx.providerCount > 1)
        'providerIds': selected.keys.toList(),
      'deliveryMode': mode,
      if (!ctx.route)
        'startDatetime': MarketTime.local(MarketTime.parse(start, ctx.zone)),
      if (!ctx.route)
        'expectedEndDatetime': MarketTime.local(
          MarketTime.parse(end, ctx.zone),
        ),
      if (ctx.route)
        'requestedPickupTime': MarketTime.local(
          MarketTime.parse(start, ctx.zone),
        ),
      if (ctx.route) 'pickup': {...point!.toJson(), 'address': address.trim()},
      if (ctx.route)
        'destination': {
          ...destination!.toJson(),
          'address': destinationAddress.trim(),
        },
      if (!isOpenRequest && !ctx.route && mode == 'CUSTOMER_TO_PROVIDER')
        'providerLocationId': first!.locationId,
      if (!ctx.route && mode == 'PROVIDER_TO_CUSTOMER')
        'meetingPoint': {
          'name': 'Service location',
          'addressLine1': address.trim(),
          ...point!.toJson(),
        },
      if (note.trim().isNotEmpty) 'customerNote': note.trim(),
      'answers': [
        for (final f in ctx.fields)
          if (f.applies(answers) &&
              answers[f.code] != null &&
              !(answers[f.code] is String &&
                  (answers[f.code] as String).trim().isEmpty))
            {'fieldId': f.id, 'value': answers[f.code]},
      ],
      if (ctx.pricingFieldIds.isNotEmpty)
        'pricingSelections': [
          for (final id in ctx.pricingFieldIds)
            {'fieldId': id, 'choiceValue': pricingSelections[id]},
        ],
      'paymentMethod': paymentMethod,
    };
  }

  Future<void> previewQuote() async {
    if (busy || !alive || uncertain || created != null) return;
    if (isOpenRequest) return;
    final epoch = _epoch;
    busy = true;
    error = null;
    _quote = null;
    _quotedInput = null;
    _notify();
    try {
      final input = bookingInput();
      final result = await repository.quote(input);
      if (!alive || epoch != _epoch) return;
      _quote = result;
      _quotedInput = jsonEncode(input);
    } catch (e) {
      if (alive && epoch == _epoch) await _failure(e);
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> submit() async {
    if (busy || !alive || uncertain || created != null) return;
    Map<String, Object?> input;
    try {
      input = bookingInput();
    } catch (e) {
      await _failure(e);
      _notify();
      return;
    }
    final epoch = ++_epoch;
    busy = true;
    error = null;
    _notify();
    try {
      final policy = await repository.requestPolicy(key.optionId);
      if (!alive || epoch != _epoch) return;
      requestPolicy = policy;
      if (isOpenRequest && !usesRequestPolicy) {
        throw const BookingProblem(
          'Open requests are not enabled for this service yet. Please contact support.',
        );
      }
      final result = usesRequestPolicy
          ? await _createScheduledRequest(epoch)
          : await repository.book(input);
      if (!alive || epoch != _epoch) return;
      if (!usesRequestPolicy &&
          (result['serviceTypeId'] != key.serviceId ||
              result['optionId'] != key.optionId)) {
        throw const FormatException('Invalid created booking');
      }
      created = result;
      stage = BookingStage.created;
    } catch (e) {
      if (alive && epoch == _epoch) {
        uncertain =
            e is NetworkException ||
            e is FormatException ||
            e is BookingProblem && (e.status ?? 0) >= 500;
        await _failure(e);
        if (!alive || epoch != _epoch) return;
        if (uncertain) {
          error = 'The booking result is uncertain. Check your booking history before making another request. No automatic retry was sent.';
        } else if (e is BookingProblem &&
            {400, 403, 404, 409}.contains(e.status)) {
          _resetSearch();
          stage = BookingStage.details;
          if (e.eligibility) await _refreshEligibility(epoch);
        }
      }
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<Map<String, dynamic>> _createScheduledRequest(int epoch) async {
    if (context!.providerCount != 1 || !{'CARD', 'WALLET'}.contains(method)) {
      throw const BookingProblem(
        'This request supports one provider and Card or Wallet payment.',
      );
    }
    final booking = bookingInput();
    final criteria = searchInput(locationStep: true);
    final input = <String, Object?>{
      'marketId': key.marketId,
      'booking': booking,
      if (mode != 'ONLINE') 'radiusKm': radius,
      if (mode == 'CUSTOMER_TO_PROVIDER') 'searchLocation': point!.toJson(),
      'languages': criteria['languages'],
      'requiredSkillIds': criteria['requiredSkillIds'],
      if (criteria.containsKey('providerFilters'))
        'providerFilters': criteria['providerFilters'],
    };
    final store = discovery.selectionStore.store;
    final storeKey =
        'bthere.customer.request.v1.${Uri.encodeComponent(discovery.selectionStore.apiScope)}.$userId.${key.marketId}.${key.serviceId}.${key.optionId}';
    final serialized = jsonEncode(input);
    final saved = await store.read(storeKey);
    final pending = saved == null ? null : jsonDecode(saved) as Map;
    if (pending != null && pending['input'] != serialized) {
      throw const BookingProblem(
        'A previous request is still unconfirmed. Restore its details before retrying, or contact support.',
      );
    }
    final random = math.Random.secure();
    final idempotencyKey =
        pending?['key'] as String? ??
        base64UrlEncode(List.generate(24, (_) => random.nextInt(256)))
            .replaceAll('=', '');
    // Pending identity and payload use the existing encrypted device driver,
    // scoped to API, account and option. No card credentials are ever included.
    if (pending == null) {
      await store.write(
        storeKey,
        jsonEncode({'key': idempotencyKey, 'input': serialized}),
      );
    }
    if (!alive || epoch != _epoch) {
      throw const BookingProblem('Please sign in again.');
    }
    try {
      final response = await repository.createRequest(input, idempotencyKey);
      if (response['selectionMode'] !=
          context!.option['providerSelectionMode']) {
        throw const FormatException('Request mode mismatch');
      }
      try {
        await store.delete(storeKey);
      } catch (_) {
        /* Do not hide confirmed creation after cleanup failure. */
      }
      return {
        ...response,
        'serviceTypeId': key.serviceId,
        'optionId': key.optionId,
        'paymentMethod': method,
      };
    } on BookingProblem catch (failure) {
      if ({400, 403, 404, 409}.contains(failure.status)) {
        try {
          await store.delete(storeKey);
        } catch (_) {
          /* Original failure remains actionable. */
        }
      }
      rethrow;
    }
  }

  Future<void> refreshCreatedRequest() async {
    final id = created?['requestId'];
    if (busy || !alive || id is! int) return;
    final epoch = _epoch;
    busy = true;
    error = null;
    _notify();
    try {
      final value = await repository.readRequest(id);
      if (alive && epoch == _epoch && value['requestId'] == id) {
        created = {...created!, ...value};
      }
    } catch (failure) {
      if (alive && epoch == _epoch) await _failure(failure);
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _refreshEligibility(int epoch) async {
    try {
      final values = await Future.wait<Object>([
        repository.requirements(key),
        repository.eligibility(key),
      ]);
      if (alive && epoch == _epoch) {
        requirements = values[0] as List<CustomerRequirement>;
        access = values[1] as Map<String, dynamic>;
        for (final r in requirements) {
          if (!dirtyRequirements.contains(r.field.id)) {
            requirementAnswers[r.field.id] = r.value;
            expiry[r.field.id] = r.expires;
          }
        }
      }
    } catch (e) {
      if (alive && epoch == _epoch) await _failure(e);
    }
  }

  Future<void> pay() async {
    if (created?['requestId'] is int) {
      await confirmRequestWallet();
      return;
    }
    if (busy ||
        !alive ||
        created == null ||
        !{'CARD', 'WALLET'}.contains(created!['paymentMethod'])) {
      return;
    }
    final epoch = _epoch;
    _startPaymentPresentation();
    busy = true;
    error = null;
    _notify();
    try {
      final settings = await repository.capabilities();
      if (!alive || epoch != _epoch) return;
      capabilities = settings;
      final method = created!['paymentMethod'];
      if (method == 'CARD' && settings['cardCheckout'] != true ||
          method == 'WALLET' && settings['bookingReservations'] != true) {
        throw const BookingProblem(
          'This payment method is currently unavailable.',
        );
      }
      final operation = await repository.pay(
        positiveId(created!['jobId']),
        created!['paymentMethod'] as String,
      );
      if (!alive || epoch != _epoch) return;
      final history = await repository.history();
      if (!alive || epoch != _epoch) return;
      payment = operation;
      for (final row in history) {
        if (row['jobId'] == created!['jobId']) created = row;
      }
    } catch (e) {
      if (alive && epoch == _epoch) {
        _paymentFailure(e);
        await _failure(e);
      }
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> confirmRequestWallet() async {
    final id = created?['requestId'];
    if (busy || !alive || id is! int || created?['paymentMethod'] != 'WALLET') {
      return;
    }
    final epoch = _epoch;
    _startPaymentPresentation();
    busy = true;
    error = null;
    _notify();
    try {
      final latest = await repository.readRequest(id);
      if (!alive || epoch != _epoch) return;
      if (latest['requestId'] != id ||
          (latest['paymentMethod'] != null &&
              latest['paymentMethod'] != 'WALLET')) {
        throw const FormatException('Invalid wallet request identity');
      }
      created = {...created!, ...latest};
      if (latest['status'] == 'CONFIRMED' &&
          {'RESERVED', 'SETTLED'}.contains(latest['paymentStatus'])) {
        return;
      }
      if (latest['status'] != 'AWAITING_CUSTOMER_CONFIRMATION') {
        throw const BookingProblem(
          'Wallet payment is available after a provider accepts your request.',
        );
      }
      final result = await repository.confirmRequestWallet(id);
      if (!alive || epoch != _epoch) return;
      created = {...created!, ...result};
    } catch (failure) {
      if (alive && epoch == _epoch) {
        _paymentFailure(failure);
        await _failure(failure);
      }
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> mockPayment(String outcome) async {
    if (busy ||
        !alive ||
        created == null ||
        payment?['intentId'] is! int ||
        created!['paymentMethod'] != 'CARD') {
      return;
    }
    final epoch = _epoch;
    _startPaymentPresentation();
    busy = true;
    error = null;
    _notify();
    try {
      final operation = await repository.mockCardEvent(
        payment!['intentId'] as int,
        outcome,
      );
      if (!alive || epoch != _epoch) return;
      final history = await repository.history();
      if (!alive || epoch != _epoch) return;
      payment = operation;
      for (final row in history) {
        if (row['jobId'] == created!['jobId']) created = row;
      }
    } catch (e) {
      if (alive && epoch == _epoch) {
        _paymentFailure(e);
        await _failure(e);
      }
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<String> upload(
    BookingField field,
    Uint8List bytes,
    String name,
  ) async {
    final key = await chooseUpload(field, () async => (bytes, name));
    return key ?? (throw const BookingProblem('No file was selected.'));
  }

  Future<String?> chooseUpload(
    BookingField field,
    Future<(Uint8List, String)?> Function() choose,
  ) async {
    if (busy || !alive) {
      throw const BookingProblem('Please wait before uploading.');
    }
    final epoch = _epoch;
    busy = true;
    _notify();
    try {
      final selected = await choose();
      if (selected == null) return null;
      if (!alive || epoch != _epoch) {
        throw const BookingProblem(
          'The service request changed. Choose the file again.',
        );
      }
      final key = await repository.upload(field, selected.$1, selected.$2);
      if (!alive || epoch != _epoch) {
        throw const BookingProblem(
          'The service request changed. Choose the file again.',
        );
      }
      return key;
    } finally {
      if (alive && epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _cancelAutoAvailability();
    _disposed = true;
    _epoch++;
    auth.removeListener(_sync);
    discovery.removeListener(_sync);
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bthere_network/bthere_network.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../profile/data/customer_profile_repository.dart';
import '../../wallet/data/customer_wallet_repository.dart'
    show walletMinorUnits;
import '../data/customer_booking_repository.dart';
import '../data/customer_request_recovery_store.dart';
import '../domain/booking_card_checkout.dart';
import '../domain/booking_models.dart';
import '../../discovery/domain/customer_discovery.dart' show object;

/// A recovered accepted request has no editable booking draft. Writes always
/// retain its ID, provider and method, and require a fresh server action window.
class CustomerRequestPaymentController extends ChangeNotifier {
  CustomerRequestPaymentController(
    this.requestId,
    this.repository,
    this.auth,
    this.now, {
    this.store,
    this.initialRequest,
  }) : owner = auth.user?.id {
    auth.addListener(_identityChanged);
  }
  final int requestId;
  final int? owner;
  final CustomerBookingRepository repository;
  final CustomerAuthController auth;
  final CustomerRequestRecoveryStore? store;
  final Map<String, dynamic>? initialRequest;
  final DateTime Function() now;
  Map<String, dynamic>? request, window;
  String? error, selectedCardLabel;
  String? paymentFailureReason;
  bool loading = true,
      working = false,
      _reading = false,
      _disposed = false,
      uncertain = false;
  bool _identityLost = false;
  bool _methodUncertain = false;
  String? _paymentBaseline;
  Completer<void>? _readFinished;
  bool get alive =>
      !_disposed &&
      !_identityLost &&
      owner != null &&
      auth.user?.id == owner &&
      auth.stage == CustomerAuthStage.authenticated;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _identityChanged() {
    if (!alive) {
      _identityLost = true;
      request = window = null;
      _notify();
    }
  }

  bool get pending =>
      uncertain ||
      {
        'PAYMENT_PENDING',
        'PAYMENT_RECONCILIATION',
      }.contains(request?['status']);
  bool get funded =>
      {
        'CONFIRMED',
        'IN_PROGRESS',
        'AWAITING_COMPLETION_CONFIRMATION',
        'COMPLETED',
      }.contains(request?['status']) &&
      {'PAID', 'RESERVED', 'SETTLED'}.contains(request?['paymentStatus']);
  bool get closed =>
      {'EXPIRED', 'CANCELLED', 'UNMATCHED'}.contains(request?['status']);
  DateTime? get deadline => DateTime.tryParse(
    '${window?['confirmationExpiresAt'] ?? request?['confirmationExpiresAt']}',
  );
  int? get seconds => deadline == null
      ? null
      : (deadline!.difference(now()).inMilliseconds / 1000).ceil().clamp(
          0,
          2147483647,
        );
  bool get canPay =>
      alive &&
      !working &&
      !_methodUncertain &&
      !pending &&
      !funded &&
      !closed &&
      window?['canPay'] == true &&
      {'WALLET', 'CARD'}.contains(request?['paymentMethod']) &&
      request?['status'] == 'AWAITING_CUSTOMER_CONFIRMATION' &&
      seconds != null &&
      seconds! > 0;
  bool get canCancel =>
      alive &&
      !working &&
      !pending &&
      !funded &&
      !closed &&
      (request?['status'] == 'MATCHING'
          ? {'NOT_STARTED', 'PENDING'}.contains(request?['paymentStatus'])
          : window?['canCancel'] == true);
  bool get failed =>
      request?['paymentStatus'] == 'FAILED' ||
      retryStartedAt != null ||
      paymentFailureReason != null;
  DateTime? get retryStartedAt => DateTime.tryParse(
    '${window?['paymentRetryStartedAt'] ?? request?['paymentRetryStartedAt']}',
  );
  void recordPaymentFailure(String message) {
    if (!alive) return;
    error = message;
    if (!pending) paymentFailureReason = message;
    _notify();
  }

  bool get checkoutFinished =>
      !alive ||
      funded ||
      closed ||
      request?['status'] == 'AWAITING_CUSTOMER_CONFIRMATION' &&
          request?['paymentStatus'] == 'FAILED';
  Future<void> refresh({bool background = false}) async {
    if (!alive || working) return;
    if (_reading) {
      await _readFinished?.future;
      return;
    }
    _reading = true;
    _readFinished = Completer<void>();
    try {
      final view = await repository.readRequest(requestId);
      if (!alive) return;
      if (view['requestId'] != requestId) {
        throw const FormatException('Wrong request');
      }
      if (view['jobId'] is int) {
        try {
          await store?.saveJobRequest(view['jobId'] as int, requestId);
        } catch (_) {}
        if (!alive) return;
      }
      String? method = view['paymentMethod'] as String?;
      _methodUncertain =
          _methodUncertain ||
          await store?.methodChangePending(requestId) == true;
      if (!alive) return;
      if (method != null && _methodUncertain) {
        _methodUncertain = false;
        await store?.saveMethod(requestId, method);
        await store?.markMethodChange(requestId, false);
      }
      method ??=
          request?['paymentMethod'] as String? ??
          initialRequest?['paymentMethod'] as String? ??
          await store?.method(requestId);
      if (method == null && view['jobId'] is int) {
        final jobs = await repository.history();
        method =
            jobs
                    .where((job) => job['jobId'] == view['jobId'])
                    .firstOrNull?['paymentMethod']
                as String?;
      }
      if (!alive) return;
      // View can omit retry metadata supplied by payment-window. Keep it while
      // the next action read is in flight so a timer rebuild cannot briefly
      // replace the failure screen with the accepted-provider screen.
      request = {
        ...view,
        'paymentMethod': ?method,
        'paymentRetryStartedAt':
            view['paymentRetryStartedAt'] ??
            window?['paymentRetryStartedAt'] ??
            request?['paymentRetryStartedAt'],
      };
      if (funded || closed) paymentFailureReason = null;
      uncertain = uncertain || await store?.uncertain(requestId) == true;
      _paymentBaseline ??= await store?.paymentBaseline(requestId);
      if (!alive) return;
      if ({
        'PAYMENT_PENDING',
        'PAYMENT_RECONCILIATION',
      }.contains(view['status'])) {
        _paymentBaseline = 'pending:PENDING';
        await store?.markPayment(requestId, true, previousStatus: 'PENDING');
      }
      final definiteFailure =
          view['status'] == 'AWAITING_CUSTOMER_CONFIRMATION' &&
          view['paymentStatus'] == 'FAILED' &&
          (!uncertain || _paymentBaseline != 'pending:FAILED');
      if (funded || closed || definiteFailure) uncertain = false;
      if (!uncertain && (funded || closed || definiteFailure)) {
        await store?.markPayment(requestId, false);
        _paymentBaseline = null;
      }
      if (!alive) return;
      if (funded || closed || view['status'] == 'MATCHING') {
        window = null;
      } else {
        final actions = await repository.paymentWindow(requestId);
        if (!alive) return;
        // The action endpoint is newer than View; never combine mismatched state.
        if (actions['status'] != view['status'] ||
            actions['paymentStatus'] != view['paymentStatus']) {
          throw const FormatException(
            'Request changed while reading payment window',
          );
        }
        window = actions;
        request = {
          ...request!,
          'confirmationExpiresAt': actions['confirmationExpiresAt'],
          'paymentRetryStartedAt': actions['paymentRetryStartedAt'],
        };
      }
    } catch (_) {
      if (alive) {
        window = null;
        if (!background || request == null) {
          error = 'Unable to check payment actions. Please retry status.';
        }
      }
    } finally {
      _reading = false;
      _readFinished?.complete();
      if (alive) {
        loading = false;
        _notify();
      }
    }
  }

  Future<Map<String, dynamic>> settings() async =>
      object(await repository.request('GET', '/me/payment-settings'));
  Future<bool> changeMethod(String method) async {
    if (!{'CARD', 'WALLET'}.contains(method) || working) return false;
    await refresh();
    if (!canPay || method == request?['paymentMethod']) return false;
    working = true;
    error = null;
    _notify();
    var changed = false;
    var sent = false;
    try {
      await store?.markMethodChange(requestId, true);
      if (!alive) return false;
      sent = true;
      final result = await repository.changePaymentMethod(requestId, method);
      if (!alive) return false;
      request = {...request!, ...result, 'paymentMethod': method};
      selectedCardLabel = null;
      changed = true;
      await store?.saveMethod(requestId, method);
      await store?.markMethodChange(requestId, false);
    } catch (failure) {
      if (alive) {
        _methodUncertain =
            !changed &&
            sent &&
            (failure is NetworkException ||
                failure is FormatException ||
                failure is BookingProblem && (failure.status ?? 0) >= 500);
        error = failure is BookingProblem ? failure.message : 'Unable to confirm the payment method. Please check request status.';
        if (!_methodUncertain) {
          try {
            await store?.markMethodChange(requestId, false);
          } catch (_) {}
        }
      }
    } finally {
      if (alive) {
        working = false;
        await refresh(background: true);
        _notify();
      }
    }
    return changed;
  }

  void clearActionError() {
    error = null;
    _notify();
  }

  Future<BookingCardCheckout?> pay({
    int? methodId,
    String? cardBrand,
    String? email,
    String? phone,
    bool mock = false,
  }) async {
    if (!alive || working) return null;
    await refresh();
    if (!canPay) return null;
    working = true;
    error = null;
    _notify();
    var sent = false;
    try {
      if (request!['paymentMethod'] == 'WALLET') {
        _paymentBaseline = 'pending:${request!['paymentStatus']}';
        await store?.markPayment(
          requestId,
          true,
          previousStatus: '${request!['paymentStatus']}',
        );
        if (!alive) return null;
        sent = true;
        final result = await repository.confirmRequestWallet(requestId);
        if (alive) request = {...request!, ...result};
      } else if (request!['paymentMethod'] == 'CARD' && mock) {
        if (methodId == null || methodId <= 0) {
          throw const BookingProblem('Choose a saved card.');
        }
        _paymentBaseline = 'pending:${request!['paymentStatus']}';
        await store?.markPayment(
          requestId,
          true,
          previousStatus: '${request!['paymentStatus']}',
        );
        if (!alive) return null;
        sent = true;
        final result = await repository.confirmMockCard(requestId, methodId);
        if (result['requestId'] != requestId) {
          throw const FormatException('Wrong payment identity');
        }
        if (alive) request = {...request!, ...result};
      } else if (request!['paymentMethod'] == 'CARD') {
        if (!{'VISA', 'MASTER'}.contains(cardBrand)) {
          throw const BookingProblem('Choose your card type.');
        }
        final profile = await CustomerProfileRepository(repository.auth).load();
        if (!alive) return null;
        final details = profile?.details;
        if (details == null ||
            !details.valid ||
            email?.trim().isNotEmpty != true ||
            phone?.trim().isNotEmpty != true) {
          throw const BookingProblem(
            'Complete your profile, email and phone details before paying by card.',
          );
        }
        // Profile/contact collection must not bypass a deadline/extension change.
        final latest = await repository.paymentWindow(requestId);
        if (!alive) return null;
        window = latest;
        if (latest['canPay'] != true ||
            DateTime.tryParse('${latest['confirmationExpiresAt']}')
                    ?.isAfter(now()) !=
                true) {
          throw const BookingProblem(
            'The payment window has ended or changed. Check request status.',
          );
        }
        _paymentBaseline = 'pending:${request!['paymentStatus']}';
        await store?.markPayment(
          requestId,
          true,
          previousStatus: '${request!['paymentStatus']}',
        );
        if (!alive) return null;
        sent = true;
        final checkout = await repository.confirmRequestCard(requestId, {
          'cardMethod': cardBrand!,
          'firstName': details.firstName,
          'lastName': details.lastName,
          'email': email!.trim(),
          'phone': phone!.trim(),
          'address': details.addressLine1,
          'city': details.city,
          'country': details.country,
        });
        if (!alive) return null;
        if (checkout.fields['currency'] != request!['currencyCode'] ||
            walletMinorUnits(checkout.fields['amount']) !=
                walletMinorUnits(request!['expectedAmount'])) {
          throw const FormatException('Checkout amount mismatch');
        }
        request = {...request!, 'status': 'PAYMENT_PENDING'};
        window = null;
        return checkout;
      }
    } catch (failure) {
      if (alive) {
        uncertain =
            sent &&
            (failure is NetworkException ||
                failure is FormatException ||
                failure is BookingProblem && (failure.status ?? 0) >= 500);
        error = uncertain
            ? 'Payment result is not confirmed yet. We are checking its status. Do not make another payment.'
            : failure is BookingProblem
            ? failure.message
            : 'Payment could not be completed. Please check the request status.';
        window = null;
        if (!uncertain) {
          paymentFailureReason = error;
          try {
            await store?.markPayment(requestId, false);
          } catch (_) {}
        }
      }
    } finally {
      if (alive) {
        working = false;
        _notify();
        await refresh(background: true);
      }
    }
    return null;
  }

  Future<void> cancel() async {
    if (!alive || working) return;
    await refresh();
    if (!canCancel) return;
    working = true;
    error = null;
    _notify();
    try {
      final result = await repository.cancelRequest(requestId);
      if (alive) request = result;
    } catch (_) {
      if (alive) {
        error =
            'Cancellation could not be confirmed. Check the request status.';
      }
    } finally {
      if (alive) {
        working = false;
        _notify();
        await refresh(background: true);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_identityChanged);
    super.dispose();
  }
}

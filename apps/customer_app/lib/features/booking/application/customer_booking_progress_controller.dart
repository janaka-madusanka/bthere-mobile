import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bthere_network/bthere_network.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../data/customer_booking_repository.dart';
import '../domain/booking_models.dart';

/// Owned job progress and explicit completion. Time never advances a service.
class CustomerBookingProgressController extends ChangeNotifier {
  CustomerBookingProgressController(
    this.repository,
    this.auth,
    this.booking, {
    this.onChanged,
  }) : owner = auth.user?.id,
       jobId = booking['jobId'] as int {
    auth.addListener(_identityChanged);
  }
  final CustomerBookingRepository repository;
  final CustomerAuthController auth;
  final VoidCallback? onChanged;
  final int? owner;
  final int jobId;
  Map<String, dynamic> booking;
  String? error;
  String? completionError;
  bool working = false,
      completionUncertain = false,
      _completionAcknowledged = false;
  Completer<void>? _readFinished;
  bool _reading = false, _disposed = false, _identityLost = false;
  bool get alive =>
      !_disposed &&
      !_identityLost &&
      owner != null &&
      auth.user?.id == owner &&
      auth.stage == CustomerAuthStage.authenticated;
  bool get active =>
      alive &&
          {
            'CONFIRMED',
            'IN_PROGRESS',
            'AWAITING_COMPLETION_CONFIRMATION',
          }.contains(booking['status']) ||
      alive && _completionAcknowledged && booking['paymentStatus'] != 'SETTLED';
  bool get _awaitingCompletion =>
      booking['status'] == 'AWAITING_COMPLETION_CONFIRMATION' &&
      (booking['paymentMethod'] == 'WALLET' &&
              booking['paymentStatus'] == 'RESERVED' ||
          booking['paymentMethod'] == 'CARD' &&
              booking['paymentStatus'] == 'PAID');
  bool get canConfirmCompletion =>
      alive && !working && !completionUncertain && _awaitingCompletion;
  bool get settlementUpdating =>
      _completionAcknowledged &&
      booking['status'] == 'COMPLETED' &&
      booking['paymentStatus'] != 'SETTLED';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _identityChanged() {
    if (!alive) {
      _identityLost = true;
      booking = {};
      error = null;
      completionError = null;
      _notify();
    }
  }

  void updateBooking(Map<String, dynamic> value) {
    if (!alive || value['jobId'] != jobId) return;
    if (_completionAcknowledged && value['status'] != 'COMPLETED') return;
    booking = value;
  }

  Future<Map<String, dynamic>?> _readOwned() async {
    final rows = await repository.history();
    if (!alive) return null;
    final latest = rows.where((row) => row['jobId'] == jobId).firstOrNull;
    if (latest == null) throw const FormatException('Booking unavailable');
    return latest;
  }

  void _apply(Map<String, dynamic> latest) {
    // A successful completion response is authoritative even if a following
    // history read briefly returns its pre-completion snapshot.
    if (_completionAcknowledged && latest['status'] != 'COMPLETED') return;
    final changed =
        booking['status'] != latest['status'] ||
        booking['paymentStatus'] != latest['paymentStatus'] ||
        booking['actualStartedAt'] != latest['actualStartedAt'] ||
        booking['actualFinishedAt'] != latest['actualFinishedAt'] ||
        booking['completionConfirmedAt'] != latest['completionConfirmedAt'];
    final hadFeedback = error != null || completionUncertain;
    booking = latest;
    error = null;
    completionUncertain = false;
    if (latest['status'] == 'COMPLETED') completionError = null;
    if (changed) onChanged?.call();
    if (changed || hadFeedback) _notify();
  }

  Future<void> refresh() async {
    if (!active || _reading || working) return;
    _reading = true;
    _readFinished = Completer<void>();
    try {
      final latest = await _readOwned();
      if (latest != null && alive) _apply(latest);
    } catch (_) {
      if (alive) {
        error = 'Unable to update service progress. Showing the last confirmed status.';
        _notify();
      }
    } finally {
      _reading = false;
      _readFinished?.complete();
    }
  }

  Future<bool> confirmCompletion() async {
    if (!canConfirmCompletion) return false;
    working = true;
    completionError = null;
    _notify();
    var sent = false;
    try {
      if (_reading) await _readFinished!.future;
      if (!alive) return false;
      final latest = await _readOwned();
      if (latest == null || !alive) return false;
      _apply(latest);
      if (booking['status'] == 'COMPLETED') return true;
      if (!_awaitingCompletion) {
        completionError =
            'This booking is not waiting for completion confirmation.';
        return false;
      }
      sent = true;
      await repository.confirmCompletion(jobId);
      if (!alive) return false;
      _completionAcknowledged = true;
      booking = {...booking, 'status': 'COMPLETED'};
      completionUncertain = false;
      onChanged?.call();
      _notify();
      return true;
    } catch (failure) {
      if (alive) {
        completionUncertain =
            sent &&
            (failure is NetworkException ||
                failure is FormatException ||
                failure is BookingProblem && (failure.status ?? 0) >= 500);
        completionError = completionUncertain
            ? 'Completion could not be verified. Check service status before trying again.'
            : failure is BookingProblem
            ? failure.message
            : 'Unable to confirm completion. Please try again.';
      }
      return false;
    } finally {
      working = false;
      if (alive) {
        _notify();
        // Read-only reconciliation; never automatically retry the POST.
        await refresh();
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

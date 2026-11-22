import 'package:flutter/foundation.dart';
import 'package:bthere_network/bthere_network.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../data/customer_booking_repository.dart';
import '../domain/booking_models.dart';
import '../domain/booking_cancellation.dart';

class CustomerCancellationController extends ChangeNotifier {
  CustomerCancellationController(
    this.repository,
    this.auth,
    this.booking, {
    this.onChanged,
  }) : owner = auth.user?.id,
       jobId = booking['jobId'] as int {
    auth.addListener(identityChanged);
  }
  final CustomerBookingRepository repository;
  final CustomerAuthController auth;
  final VoidCallback? onChanged;
  final int jobId;
  final int? owner;
  Map<String, dynamic> booking;
  BookingCancellation? preview, receipt;
  String? error;
  bool working = false, uncertain = false, disposed = false, lost = false;
  bool get alive =>
      !disposed &&
      !lost &&
      owner != null &&
      auth.user?.id == owner &&
      auth.stage == CustomerAuthStage.authenticated;
  bool get eligible =>
      alive &&
      receipt == null &&
      booking['status'] == 'CONFIRMED' &&
      {'PAID', 'RESERVED'}.contains(booking['paymentStatus']);
  void emit() {
    if (!disposed) notifyListeners();
  }

  void identityChanged() {
    if (!alive) {
      lost = true;
      preview = receipt = null;
      booking = {};
      error = null;
      emit();
    }
  }

  Future<bool> prepare() async {
    if (!eligible || working || uncertain) return false;
    working = true;
    preview = null;
    error = null;
    emit();
    try {
      final rows = await repository.history();
      if (!alive) return false;
      final latest = rows.where((r) => r['jobId'] == jobId).firstOrNull;
      if (latest == null) throw const FormatException('Booking unavailable');
      booking = latest;
      if (!eligible) {
        if (latest['status'] == 'CANCELLED') {
          final saved = await repository.cancellation(jobId);
          if (alive) apply(saved);
          return false;
        }
        onChanged?.call();
        throw const BookingProblem(
          'This booking can no longer be cancelled before service start.',
        );
      }
      final value = await repository.cancellationPreview(jobId);
      if (!alive) return false;
      preview = value;
      return true;
    } catch (failure) {
      if (alive) {
        error = failure is BookingProblem
            ? failure.message
            : 'Cancellation preview could not be loaded. Please retry.';
      }
      return false;
    } finally {
      if (alive) {
        working = false;
        emit();
      }
    }
  }

  Future<void> loadReceipt() async {
    if (!alive || working) return;
    working = true;
    error = null;
    emit();
    try {
      final result = await repository.cancellation(jobId);
      if (!alive) return;
      apply(result);
    } catch (failure) {
      if (!alive) return;
      if (uncertain && failure is BookingProblem && failure.status == 404) {
        try {
          final rows = await repository.history();
          if (!alive) return;
          final latest = rows.where((r) => r['jobId'] == jobId).firstOrNull;
          if (latest != null && latest['status'] == 'CONFIRMED') {
            booking = latest;
            uncertain = false;
          }
        } catch (_) {
          /* Keep an unknown cancellation blocked until an owned read succeeds. */
        }
      }
      error = 'Cancellation details could not be confirmed. Check again before trying another cancellation.';
    } finally {
      if (alive) {
        working = false;
        emit();
      }
    }
  }

  void apply(BookingCancellation value) {
    receipt = value;
    preview = null;
    uncertain = false;
    error = null;
    booking = {
      ...booking,
      'status': 'CANCELLED',
      'paymentStatus': value.data['paymentStatus'],
    };
    onChanged?.call();
  }

  Future<void> confirm(String reason, String note) async {
    if (!eligible || working || uncertain || preview == null) return;
    if (reason.trim().isEmpty ||
        reason.trim().length > 100 ||
        note.length > 1000) {
      error = 'Enter a reason up to 100 characters and a note up to 1000 characters.';
      emit();
      return;
    }
    working = true;
    error = null;
    emit();
    final shown = preview!;
    try {
      final result = await repository.cancelPaidBooking(
        jobId,
        shown,
        reason,
        note,
      );
      if (alive) apply(result);
    } catch (failure) {
      if (!alive) return;
      preview = null;
      uncertain =
          failure is NetworkException ||
          failure is FormatException ||
          failure is BookingProblem && (failure.status ?? 0) >= 500;
      error = uncertain
          ? 'The cancellation result is being checked. No automatic cancellation retry was sent.'
          : failure is BookingProblem
          ? failure.message
          : 'Cancellation failed. Review the latest preview.';
    } finally {
      if (alive) {
        working = false;
        emit();
      }
    }
    if (alive && uncertain) await loadReceipt();
  }

  void update(Map<String, dynamic> latest) {
    if (!alive || latest['jobId'] != jobId || receipt != null) return;
    final cancelled =
        booking['status'] != 'CANCELLED' && latest['status'] == 'CANCELLED';
    booking = latest;
    if (cancelled && !working) {
      Future.microtask(() {
        if (alive && !working) loadReceipt();
      });
    }
  }

  @override
  void dispose() {
    disposed = true;
    auth.removeListener(identityChanged);
    super.dispose();
  }
}

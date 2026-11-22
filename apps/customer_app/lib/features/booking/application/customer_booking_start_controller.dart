import 'package:flutter/foundation.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../data/customer_booking_repository.dart';
import '../domain/booking_models.dart';

/// Read-only START-code presentation. Never starts or completes a service.
class CustomerBookingStartController extends ChangeNotifier {
  CustomerBookingStartController(
    this.repository,
    this.auth,
    this.now,
    this.booking, {
    this.onBookingChanged,
  }) : owner = auth.user?.id,
       jobId = booking['jobId'] as int {
    auth.addListener(_identityChanged);
  }
  final CustomerBookingRepository repository;
  final CustomerAuthController auth;
  final DateTime Function() now;
  final int? owner;
  final int jobId;
  final VoidCallback? onBookingChanged;
  int _revealRevision = 0;
  Map<String, dynamic> booking;
  String? _code, error;
  DateTime? expiresAt;
  bool busy = false, _reading = false, _disposed = false, _identityLost = false;
  bool get alive =>
      !_disposed &&
      !_identityLost &&
      owner != null &&
      auth.user?.id == owner &&
      auth.stage == CustomerAuthStage.authenticated;
  bool get eligible =>
      alive &&
      booking['status'] == 'CONFIRMED' &&
      (booking['paymentMethod'] == 'WALLET' &&
              booking['paymentStatus'] == 'RESERVED' ||
          booking['paymentMethod'] == 'CARD' &&
              booking['paymentStatus'] == 'PAID');
  String? get code =>
      eligible && expiresAt?.isAfter(now()) == true ? _code : null;
  bool get expired => _code != null && expiresAt?.isAfter(now()) != true;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _identityChanged() {
    if (!alive) {
      _identityLost = true;
      _code = null;
      expiresAt = null;
      _notify();
    }
  }

  void updateBooking(Map<String, dynamic> value) {
    if (!alive || value['jobId'] != jobId) return;
    booking = value;
    if (!eligible) {
      _code = null;
      expiresAt = null;
      error = null;
    }
  }

  void hide() {
    _revealRevision++;
    _code = null;
    expiresAt = null;
    error = null;
    _notify();
  }

  Future<bool> _refreshBooking() async {
    final rows = await repository.history();
    if (!alive) return false;
    final latest = rows.where((row) => row['jobId'] == jobId).firstOrNull;
    if (latest == null) {
      _code = null;
      throw const BookingProblem('Booking is not available.');
    }
    final changed =
        latest['status'] != booking['status'] ||
        latest['paymentStatus'] != booking['paymentStatus'];
    updateBooking(latest);
    if (changed) onBookingChanged?.call();
    return eligible;
  }

  Future<void> load() async {
    if (!eligible || busy || _reading) return;
    busy = true;
    final revision = ++_revealRevision;
    error = null;
    _notify();
    try {
      // Recheck the owned job, rather than showing a code for stale confirmed UI.
      if (!await _refreshBooking()) return;
      final result = await repository.startCode(jobId);
      if (!alive || !eligible || revision != _revealRevision) return;
      final expiry = DateTime.parse(result['expiresAt'] as String);
      if (!expiry.isAfter(now())) {
        throw const BookingProblem(
          'The start code has expired. Please check availability again.',
        );
      }
      _code = result['code'] as String;
      expiresAt = expiry;
    } catch (failure) {
      if (!alive || revision != _revealRevision) return;
      _code = null;
      expiresAt = null;
      error = failure is BookingProblem && failure.status == 409
          ? 'The start code is not available in this booking state or outside its service window. Check again closer to the service time.'
          : failure is BookingProblem && failure.status == 404
          ? 'A start code is not available for this booking.'
          : 'Unable to load your start code. Please try again.';
    } finally {
      busy = false;
      if (alive) _notify();
    }
  }

  Future<void> refreshStatus() async {
    if (!alive || busy || _reading || _code == null) return;
    _reading = true;
    try {
      await _refreshBooking();
    } catch (_) {
      if (alive) {
        _code = null;
        error = 'Unable to verify booking status. Please check again before sharing the code.';
      }
    } finally {
      _reading = false;
      if (alive) _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _code = null;
    auth.removeListener(_identityChanged);
    super.dispose();
  }
}

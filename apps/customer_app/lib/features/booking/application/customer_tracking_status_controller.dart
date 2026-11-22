import 'package:flutter/foundation.dart';

import '../domain/booking_models.dart';
import '../domain/booking_tracking.dart';
import '../data/customer_booking_repository.dart';
import '../../auth/application/customer_auth_controller.dart';

class CustomerTrackingStatusController extends ChangeNotifier {
  CustomerTrackingStatusController(this.repository, this.auth, this.jobId)
    : owner = auth.user?.id {
    auth.addListener(identityChanged);
  }
  final CustomerBookingRepository repository;
  final CustomerAuthController auth;
  final int jobId;
  final int? owner;
  BookingTrackingStatus? status;
  String? error;
  bool reading = false, disposed = false, lost = false, unavailable = false;
  bool get alive =>
      !disposed &&
      !lost &&
      owner != null &&
      auth.user?.id == owner &&
      auth.stage == CustomerAuthStage.authenticated;
  bool get polls => alive && !unavailable && status?.polls == true;
  void emit() {
    if (!disposed) notifyListeners();
  }

  void identityChanged() {
    if (!alive) {
      lost = true;
      status = null;
      error = null;
      emit();
    }
  }

  Future<void> refresh() async {
    if (!alive || reading) return;
    reading = true;
    if (status == null) emit();
    try {
      final result = await repository.trackingStatus(jobId);
      if (!alive) return;
      unavailable = false;
      final changed = error != null || status?.signature != result.signature;
      status = result;
      error = null;
      if (changed) emit();
    } catch (failure) {
      if (!alive) return;
      unavailable = failure is BookingProblem && failure.status == 404;
      error = unavailable
          ? 'Tracking is not available for this booking.'
          : 'Tracking updates could not be loaded. Please check again.';
      emit();
    } finally {
      reading = false;
      if (alive && status == null) emit();
    }
  }

  @override
  void dispose() {
    disposed = true;
    auth.removeListener(identityChanged);
    super.dispose();
  }
}

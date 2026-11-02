import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import '../data/customer_profile_repository.dart';
import '../domain/customer_profile.dart';

final customerProfileRepositoryProvider = Provider<CustomerProfileRepository>(
  (ref) => CustomerProfileRepository(ref.watch(customerAuthServiceProvider)),
  dependencies: [customerAuthServiceProvider],
);
final customerProfileControllerProvider = Provider<CustomerProfileController>(
  (ref) {
    final controller = CustomerProfileController(
      ref.watch(customerProfileRepositoryProvider),
      ref.watch(customerAuthControllerProvider),
    );
    ref.onDispose(controller.dispose);
    return controller;
  },
  dependencies: [
    customerProfileRepositoryProvider,
    customerAuthControllerProvider,
  ],
);

enum CustomerProfileStage { idle, loading, missing, ready, failure }

class CustomerProfileController extends ChangeNotifier {
  CustomerProfileController(this.repository, this.auth) {
    auth.addListener(_sync);
    _sync();
  }
  final CustomerProfileRepository repository;
  final CustomerAuthController auth;
  CustomerProfileStage stage = CustomerProfileStage.idle;
  CustomerProfile? profile;
  String? error;
  bool saving = false, _disposed = false;
  int? _userId;
  int _epoch = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sync() {
    if (auth.stage != CustomerAuthStage.authenticated) {
      _epoch++;
      _userId = null;
      profile = null;
      error = null;
      stage = CustomerProfileStage.idle;
      _notify();
    } else if (_userId != auth.user?.id) {
      _userId = auth.user?.id;
      load();
    }
  }

  Future<void> load() async {
    if (stage == CustomerProfileStage.loading || saving || _userId == null) {
      return;
    }
    final epoch = ++_epoch;
    stage = CustomerProfileStage.loading;
    error = null;
    _notify();
    try {
      final value = await repository.load();
      if (_disposed || epoch != _epoch) return;
      if (value != null && value.userId != _userId) {
        throw const FormatException('Profile owner mismatch');
      }
      if (value != null && value.status != 'ACTIVE') {
        throw const CustomerAuthFailure('This Customer profile is not active.');
      }
      profile = value;
      stage = value != null && value.profileCompleted
          ? CustomerProfileStage.ready
          : CustomerProfileStage.missing;
    } catch (failure) {
      if (_disposed || epoch != _epoch) return;
      stage = CustomerProfileStage.failure;
      error = 'Unable to load your profile. Please try again.';
      await _checkSession(failure);
    } finally {
      if (epoch == _epoch) _notify();
    }
  }

  Future<void> save(CustomerProfileInput input) async {
    if (saving || _userId == null || stage == CustomerProfileStage.loading) {
      return;
    }
    final epoch = _epoch;
    saving = true;
    error = null;
    _notify();
    try {
      final value = await repository.save(input);
      if (_disposed || epoch != _epoch) return;
      if (value.userId != _userId) {
        throw const FormatException('Profile owner mismatch');
      }
      if (value.status != 'ACTIVE') {
        throw const CustomerAuthFailure('This Customer profile is not active.');
      }
      profile = value;
      stage = value.profileCompleted
          ? CustomerProfileStage.ready
          : CustomerProfileStage.missing;
    } catch (failure) {
      if (_disposed || epoch != _epoch) return;
      error = failure is CustomerAuthFailure
          ? failure.message
          : 'Unable to save your profile. Please try again.';
      await _checkSession(failure);
    } finally {
      saving = false;
      if (epoch == _epoch) _notify();
    }
  }

  Future<void> _checkSession(Object failure) async {
    if (failure is CustomerAuthFailure && failure.status == 401) {
      await auth.restore();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    auth.removeListener(_sync);
    super.dispose();
  }
}

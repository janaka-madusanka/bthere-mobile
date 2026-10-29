import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_providers.dart';
import '../data/customer_auth_service.dart';

final customerAuthServiceProvider = Provider<CustomerAuthService>(
  (ref) => CustomerAuthService(
    ref.watch(customerApiClientProvider),
    ref.watch(customerSessionStorageProvider),
    now: ref.watch(customerClockProvider),
  ),
  dependencies: [
    customerApiClientProvider,
    customerSessionStorageProvider,
    customerClockProvider,
  ],
);

final customerAuthControllerProvider = Provider<CustomerAuthController>((ref) {
  final controller = CustomerAuthController(
    ref.watch(customerAuthServiceProvider),
  );
  ref.onDispose(controller.dispose);
  controller.restore();
  return controller;
}, dependencies: [customerAuthServiceProvider]);

enum CustomerVerificationChannel { email, phone }

enum CustomerAuthStage { checking, signedOut, authenticated, failure }

class CustomerAuthController extends ChangeNotifier {
  CustomerAuthController(this.service);
  final CustomerAuthService service;
  CustomerAuthStage stage = CustomerAuthStage.checking;
  SessionUser? user;
  CustomerVerificationChannel? verificationSuccess;
  String? verificationEmail, verificationPhone, error;
  DateTime? resendAt;
  bool busy = false;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    if (busy) return;
    verificationSuccess = null;
    stage = CustomerAuthStage.checking;
    await _run(() async {
      user = await service.restore();
      stage = user == null
          ? CustomerAuthStage.signedOut
          : CustomerAuthStage.authenticated;
    }, startup: true);
  }

  Future<void> login(String identifier, String password) async {
    if (identifier.trim().isEmpty || password.trim().isEmpty) {
      error = 'Enter your email or username and password.';
      _notify();
      return;
    }
    await _run(() async {
      final session = await service.login(identifier, password);
      user = await service.restore();
      if (user == null || session.user == null) {
        throw const CustomerAuthFailure('Please sign in again.');
      }
      verificationEmail = null;
      stage = CustomerAuthStage.authenticated;
    });
  }

  Future<void> register(String email, String password) async {
    if (!validEmail(email) ||
        password.runes.length < 10 ||
        password.runes.length > 72) {
      error = 'Enter a valid email and a password of 10–72 characters.';
      _notify();
      return;
    }
    await _run(() async {
      await service.register(email, password);
      verificationEmail = email.trim().toLowerCase();
      resendAt = service.now().add(const Duration(seconds: 60));
    });
  }

  Future<void> requestPhoneOtp(String phoneNumber) async {
    if (busy) return;
    if (!validPhoneNumber(phoneNumber)) {
      error =
          'Enter a phone number with country code, for example +94771234567.';
      _notify();
      return;
    }
    if (resendAt?.isAfter(service.now()) ?? false) return;
    await _run(() async {
      await service.requestPhoneOtp(phoneNumber);
      verificationEmail = null;
      verificationPhone = phoneNumber.trim();
      resendAt = service.now().add(const Duration(seconds: 60));
    });
  }

  Future<void> verifyPhoneOtp(String otp) async {
    final phone = verificationPhone;
    if (phone == null || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      error = 'Enter the six-digit verification code.';
      _notify();
      return;
    }
    await _run(() async {
      await service.verifyPhoneOtp(phone, otp);
      user = await service.restore();
      if (user == null) {
        throw const CustomerAuthFailure('Please sign in again.');
      }
      verificationPhone = null;
      resendAt = null;
      verificationSuccess = CustomerVerificationChannel.phone;
      stage = CustomerAuthStage.authenticated;
    });
  }

  Future<void> verify(String otp) async {
    final email = verificationEmail;
    if (email == null || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      error = 'Enter the six-digit verification code.';
      _notify();
      return;
    }
    await _run(() async {
      await service.verify(email, otp);
      user = await service.restore();
      if (user == null) {
        throw const CustomerAuthFailure('Please sign in again.');
      }
      verificationEmail = null;
      verificationSuccess = CustomerVerificationChannel.email;
      stage = CustomerAuthStage.authenticated;
    });
  }

  Future<void> resend() async {
    final phone = verificationPhone;
    if (phone != null) {
      await requestPhoneOtp(phone);
      return;
    }
    final email = verificationEmail;
    if (email == null || (resendAt?.isAfter(service.now()) ?? false)) return;
    await _run(() async {
      await service.resend(email);
      resendAt = service.now().add(const Duration(seconds: 60));
    });
  }

  Future<void> resumeVerification(String email) async {
    if (busy) return;
    if (!validEmail(email)) {
      error = 'Enter your email address to request a verification code.';
      _notify();
      return;
    }
    final normalized = email.trim().toLowerCase();
    // A generic resend response never confirms whether this account exists.
    verificationEmail = normalized;
    await _run(() async {
      await service.resend(normalized);
      resendAt = service.now().add(const Duration(seconds: 60));
    });
  }

  void cancelVerification() {
    if (busy) return;
    verificationEmail = null;
    verificationPhone = null;
    error = null;
    _notify();
  }

  void continueAfterVerification() {
    if (busy ||
        stage != CustomerAuthStage.authenticated ||
        verificationSuccess == null) {
      return;
    }
    verificationSuccess = null;
    _notify();
  }

  Future<void> logout({bool all = false}) => _run(() async {
    await service.logout(all: all);
    user = null;
    verificationSuccess = null;
    verificationEmail = null;
    verificationPhone = null;
    resendAt = null;
    stage = CustomerAuthStage.signedOut;
  });

  Future<void> _run(
    Future<void> Function() task, {
    bool startup = false,
  }) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      await task();
    } on CustomerAuthFailure catch (failure) {
      error = failure.message;
      if (failure.retryAt != null) resendAt = failure.retryAt;
      if (failure.status == 401) {
        user = null;
        verificationSuccess = null;
        stage = CustomerAuthStage.signedOut;
      } else if (startup) {
        stage = CustomerAuthStage.failure;
      }
    } on NetworkException catch (failure) {
      error = switch (failure.kind) {
        NetworkExceptionKind.timeout =>
          'The request timed out. Please try again.',
        NetworkExceptionKind.cancelled =>
          'The request was cancelled. Please try again.',
        NetworkExceptionKind.badResponse =>
          'The server could not complete the request. Please try again.',
        _ => 'Unable to reach the sign-in service. Please try again shortly.',
      };
      if (startup) stage = CustomerAuthStage.failure;
    } catch (_) {
      error = 'Unable to complete the request. Please try again.';
      if (startup) stage = CustomerAuthStage.failure;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool validEmail(String value) =>
    value.trim().length <= 254 &&
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

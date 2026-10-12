import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import 'auth_submission_state.dart';
import '../../onboarding/application/provider_entry_gate.dart';

/// Transient route context; no password/OTP and no URL query parameters.
final class EmailVerificationContext {
  const EmailVerificationContext(this.email);
  final String email;
}

final emailVerificationControllerProvider =
    NotifierProvider.autoDispose<
      EmailVerificationController,
      AuthSubmissionState<AuthUser>
    >(
      EmailVerificationController.new,
      dependencies: [
        providerAuthRepositoryProvider,
        appSessionStateProvider,
        providerEntryGateProvider,
      ],
    );

class EmailVerificationController
    extends Notifier<AuthSubmissionState<AuthUser>> {
  @override
  AuthSubmissionState<AuthUser> build() => const AuthSubmissionState();

  Future<void> submit({required String email, required String otp}) async {
    if (state.loading || state.value != null) return;
    state = const AuthSubmissionState(loading: true);
    try {
      final result = await ref
          .read(providerAuthRepositoryProvider)
          .verifyProviderEmail(
            EmailOtpVerificationRequest(email: email.trim(), otp: otp.trim()),
          );
      if (!ref.mounted) return;
      switch (result) {
        case Success<AuthUser>(:final value):
          ref.read(providerEntryGateProvider.notifier).requireDetails();
          state = AuthSubmissionState(value: value);
          // Auth has already awaited persistence. Routing observes this local
          // reread instead of treating repository success as authentication.
          ref.invalidate(appSessionStateProvider);
        case Failure<AuthUser>(:final failure):
          state = AuthSubmissionState(failure: safeAuthFailure(failure));
      }
    } catch (_) {
      if (ref.mounted) {
        state = const AuthSubmissionState(failure: unexpectedAuthFailure);
      }
    }
  }
}

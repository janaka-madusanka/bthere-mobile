import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../domain/google_identity_provider.dart';
import 'auth_submission_state.dart';

final googleAuthControllerProvider =
    NotifierProvider.autoDispose<
      GoogleAuthController,
      AuthSubmissionState<AuthUser>
    >(
      GoogleAuthController.new,
      dependencies: [
        googleIdentityProvider,
        providerAuthRepositoryProvider,
        appSessionStateProvider,
      ],
    );

class GoogleAuthController extends Notifier<AuthSubmissionState<AuthUser>> {
  @override
  AuthSubmissionState<AuthUser> build() => const AuthSubmissionState();

  Future<void> submit() async {
    if (state.loading) return;
    state = const AuthSubmissionState(loading: true);
    try {
      final idToken = await ref.read(googleIdentityProvider).requestIdToken();
      if (!ref.mounted) return;
      if (idToken == null) {
        state = const AuthSubmissionState();
        return;
      }
      if (idToken.trim().isEmpty) {
        state = const AuthSubmissionState(failure: googleMissingTokenFailure);
        return;
      }
      final result = await ref
          .read(providerAuthRepositoryProvider)
          .authenticateProviderWithGoogle(idToken);
      if (!ref.mounted) return;
      switch (result) {
        case Success<AuthUser>(:final value):
          state = AuthSubmissionState(value: value);
          ref.invalidate(appSessionStateProvider);
        case Failure<AuthUser>(:final failure):
          state = AuthSubmissionState(failure: safeAuthFailure(failure));
      }
    } on GoogleIdentityFailure catch (error) {
      if (ref.mounted) {
        state = AuthSubmissionState(failure: safeAuthFailure(error.failure));
      }
    } catch (_) {
      if (ref.mounted) {
        state = const AuthSubmissionState(failure: unexpectedAuthFailure);
      }
    }
  }
}

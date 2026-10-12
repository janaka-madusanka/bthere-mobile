import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import 'auth_submission_state.dart';

final emailRegistrationControllerProvider =
    NotifierProvider.autoDispose<
      EmailRegistrationController,
      AuthSubmissionState<RegistrationAccount>
    >(
      EmailRegistrationController.new,
      dependencies: [providerAuthRepositoryProvider],
    );

class EmailRegistrationController
    extends Notifier<AuthSubmissionState<RegistrationAccount>> {
  @override
  AuthSubmissionState<RegistrationAccount> build() =>
      const AuthSubmissionState();

  Future<RegistrationAccount?> submit({
    required String email,
    required String password,
  }) async {
    if (state.loading || state.value != null) return null;
    state = const AuthSubmissionState(loading: true);
    try {
      final result = await ref
          .read(providerAuthRepositoryProvider)
          .registerProviderWithEmail(
            ProviderEmailRegistrationRequest(
              email: email.trim(),
              password: password,
            ),
          );
      if (!ref.mounted) return null;
      switch (result) {
        case Success<RegistrationAccount>(:final value):
          state = AuthSubmissionState(value: value);
          return value;
        case Failure<RegistrationAccount>(:final failure):
          state = AuthSubmissionState(failure: safeAuthFailure(failure));
      }
    } catch (_) {
      if (ref.mounted) {
        state = const AuthSubmissionState(failure: unexpectedAuthFailure);
      }
    }
    return null;
  }
}

import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import 'auth_submission_state.dart';

final loginControllerProvider =
    NotifierProvider.autoDispose<
      LoginController,
      AuthSubmissionState<AuthUser>
    >(
      LoginController.new,
      dependencies: [providerAuthRepositoryProvider, appSessionStateProvider],
    );

class LoginController extends Notifier<AuthSubmissionState<AuthUser>> {
  @override
  AuthSubmissionState<AuthUser> build() => const AuthSubmissionState();

  Future<void> submit({
    required String identifier,
    required String password,
  }) async {
    if (state.loading || identifier.trim().isEmpty || password.isEmpty) return;
    state = const AuthSubmissionState(loading: true);
    try {
      final result = await ref
          .read(providerAuthRepositoryProvider)
          .loginProvider(identifier: identifier.trim(), password: password);
      if (!ref.mounted) return;
      switch (result) {
        case Success<AuthUser>(:final value):
          state = AuthSubmissionState(value: value);
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

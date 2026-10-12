import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../core/session/app_session_state.dart';
import '../domain/provider_completion.dart';

final providerCompletionControllerProvider =
    AsyncNotifierProvider<
      ProviderCompletionController,
      Result<ProviderCompletion>?
    >(
      ProviderCompletionController.new,
      dependencies: [
        appSessionStateProvider,
        providerCompletionRepositoryProvider,
      ],
    );

final class ProviderCompletionController
    extends AsyncNotifier<Result<ProviderCompletion>?> {
  @override
  Future<Result<ProviderCompletion>?> build() async {
    final session = await ref.watch(appSessionStateProvider.future);
    if (!ref.mounted || session != AppSessionState.authenticated) return null;
    try {
      return await ref
          .watch(providerCompletionRepositoryProvider)
          .loadCompletion();
    } catch (_) {
      return const Failure(
        AppFailure(
          message: 'Unable to check your account setup. Please try again.',
          code: 'ONBOARDING_OPERATION_FAILED',
        ),
      );
    }
  }

  /// Invalidates the cached completion after a future onboarding update.
  /// Concurrent refresh requests share the current check; no polling is used.
  void reload() {
    if (!state.isLoading) ref.invalidateSelf();
  }
}

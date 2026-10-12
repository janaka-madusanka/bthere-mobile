import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../core/session/app_session_state.dart';
import '../domain/provider_completion.dart';
import 'provider_completion_controller.dart';

/// Account prerequisites only. Service requirement status does not guard routes.
final providerEntryGateProvider =
    AsyncNotifierProvider<ProviderEntryGate, Result<bool>?>(
      ProviderEntryGate.new,
      dependencies: [
        appSessionStateProvider,
        providerCompletionControllerProvider,
      ],
    );

class ProviderEntryGate extends AsyncNotifier<Result<bool>?> {
  bool _newlyVerified = false;

  @override
  Future<Result<bool>?> build() async {
    final session = await ref.watch(appSessionStateProvider.future);
    if (!ref.mounted) return null;
    if (session != AppSessionState.authenticated) {
      _newlyVerified = false;
      return null;
    }
    // Fresh registration is definitively unfinished; no missing-profile guess.
    if (_newlyVerified) return const Success(true);
    try {
      // Read once per authenticated entry. Later service setup refreshes must
      // not replace an in-progress service route with account onboarding.
      final completion = await ref.read(
        providerCompletionControllerProvider.future,
      );
      return switch (completion) {
        Success<ProviderCompletion>(:final value) => Success(
          !value.profileCompleted ||
              !value.marketSelected ||
              value.nextStep == ProviderOnboardingStep.completeProfile ||
              value.nextStep == ProviderOnboardingStep.selectMarket,
        ),
        Failure<ProviderCompletion>(:final failure) => Failure<bool>(failure),
        _ => const Failure<bool>(entryCheckFailure),
      };
    } catch (_) {
      return const Failure<bool>(entryCheckFailure);
    }
  }

  /// Called only after verification has securely persisted the session.
  void requireDetails() {
    _newlyVerified = true;
    state = const AsyncData(Success(true));
  }

  /// Acknowledged authenticated profile PUT includes the selected market.
  void profileSaved() {
    _newlyVerified = false;
    state = const AsyncData(Success(false));
  }

  void retry() {
    if (state.isLoading) return;
    ref.invalidate(providerCompletionControllerProvider);
    ref.invalidateSelf();
  }
}

const entryCheckFailure = AppFailure(
  message: 'Unable to check your account setup. Please try again.',
  code: 'PROVIDER_ENTRY_CHECK_FAILED',
);

import '../../markets/application/provider_market_controller.dart';
import '../../markets/domain/provider_market.dart';

import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_providers.dart';
import '../../application/provider_completion_controller.dart';
import '../domain/provider_profile_input.dart';
import '../data/provider_profile_reader.dart';

final class ProfileSubmissionState {
  const ProfileSubmissionState({
    this.loading = false,
    this.saved = false,
    this.failure,
  });
  final bool loading, saved;
  final AppFailure? failure;
}

final providerProfileControllerProvider =
    NotifierProvider.autoDispose<
      ProviderProfileController,
      ProfileSubmissionState
    >(
      ProviderProfileController.new,
      dependencies: [
        providerProfileRepositoryProvider,
        clockProvider,
        providerCompletionControllerProvider,
        providerMarketControllerProvider,
        providerProfileDetailsProvider,
      ],
    );

final class ProviderProfileController extends Notifier<ProfileSubmissionState> {
  @override
  ProfileSubmissionState build() => const ProfileSubmissionState();
  Future<void> submit(ProviderProfileInput input) async {
    if (state.loading || state.saved) return;
    final validation = input.validationMessage(ref.read(clockProvider)());
    if (validation != null) {
      state = ProfileSubmissionState(
        failure: AppFailure(
          message: validation,
          code: 'PROFILE_VALIDATION_FAILED',
        ),
      );
      return;
    }
    final markets = ref.read(providerMarketControllerProvider);
    final result = markets.asData?.value;
    if (markets.isLoading ||
        markets.hasError ||
        result is! Success<List<ProviderMarket>> ||
        !result.value.any(
          (market) => market.id == input.marketId && market.status == 'ACTIVE',
        )) {
      state = const ProfileSubmissionState(
        failure: AppFailure(
          message: 'Select an available market before continuing.',
          code: 'PROFILE_MARKET_REQUIRED',
        ),
      );
      return;
    }
    state = const ProfileSubmissionState(loading: true);
    try {
      final result = await ref
          .read(providerProfileRepositoryProvider)
          .updateProfile(input);
      if (!ref.mounted) return;
      switch (result) {
        case Success<void>():
          ref.invalidate(providerProfileDetailsProvider);
          final completion = ref.read(
            providerCompletionControllerProvider.notifier,
          );
          state = const ProfileSubmissionState(saved: true);
          completion.reload();
        case Failure<void>(:final failure):
          state = ProfileSubmissionState(
            failure: AppFailure(message: failure.message, code: failure.code),
          );
      }
    } catch (_) {
      if (ref.mounted) {
        state = const ProfileSubmissionState(
          failure: AppFailure(
            message: 'Unable to save your profile. Please try again.',
            code: 'PROFILE_UI_OPERATION_FAILED',
          ),
        );
      }
    }
  }
}

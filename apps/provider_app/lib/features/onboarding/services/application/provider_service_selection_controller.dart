import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/session/app_session_state.dart';
import '../../application/provider_completion_controller.dart';
import '../domain/provider_service_assignment.dart';
import '../domain/provider_service_input.dart';
import '../domain/provider_service_type.dart';
import 'provider_service_catalog_controller.dart';

final class ServiceSelectionState {
  const ServiceSelectionState({
    this.loading = false,
    this.assignment,
    this.failure,
  });
  final bool loading;
  final ProviderServiceAssignment? assignment;
  final AppFailure? failure;
}

// Retained across destination routing for later onboarding APIs; reset on session changes.
final providerServiceSelectionProvider =
    NotifierProvider<ProviderServiceSelectionController, ServiceSelectionState>(
      ProviderServiceSelectionController.new,
      dependencies: [
        appSessionStateProvider,
        providerServiceRepositoryProvider,
        providerServiceCatalogProvider,
        providerCompletionControllerProvider,
      ],
    );

final class ProviderServiceSelectionController
    extends Notifier<ServiceSelectionState> {
  @override
  ServiceSelectionState build() {
    ref.watch(appSessionStateProvider);
    return const ServiceSelectionState();
  }

  Future<void> submit(ProviderServiceInput input) async {
    if (state.loading || state.assignment != null) return;
    final session = ref.read(appSessionStateProvider).asData?.value;
    final catalog = ref.read(providerServiceCatalogProvider);
    final result = catalog.asData?.value;
    if (session != AppSessionState.authenticated ||
        !input.isValid ||
        catalog.isLoading ||
        catalog.hasError ||
        result is! Success<List<ProviderServiceType>> ||
        !result.value.any(
          (service) =>
              service.id == input.providerTypeId && service.status == 'ACTIVE',
        )) {
      state = const ServiceSelectionState(
        failure: AppFailure(
          message:
              'Select an available service and enter valid experience years.',
          code: 'SERVICE_SELECTION_INVALID',
        ),
      );
      return;
    }
    final sessionState = ref.read(appSessionStateProvider);
    state = const ServiceSelectionState(loading: true);
    try {
      final response = await ref
          .read(providerServiceRepositoryProvider)
          .addService(input);
      // A result from a previous session must not affect a new session.
      if (!ref.mounted ||
          !identical(ref.read(appSessionStateProvider), sessionState)) {
        return;
      }
      switch (response) {
        case Success<ProviderServiceAssignment>(:final value):
          state = ServiceSelectionState(assignment: value);
          ref.read(providerCompletionControllerProvider.notifier).reload();
        case Failure<ProviderServiceAssignment>(:final failure):
          state = ServiceSelectionState(
            failure: AppFailure(message: failure.message, code: failure.code),
          );
      }
    } catch (_) {
      if (ref.mounted &&
          identical(ref.read(appSessionStateProvider), sessionState)) {
        state = const ServiceSelectionState(
          failure: AppFailure(
            message: 'Unable to add your service. Please try again.',
            code: 'SERVICE_SUBMISSION_FAILED',
          ),
        );
      }
    }
  }
}

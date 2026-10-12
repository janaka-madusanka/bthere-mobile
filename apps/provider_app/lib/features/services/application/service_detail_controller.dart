import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../../onboarding/services/application/provider_service_catalog_controller.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../onboarding/services/domain/provider_service_input.dart';
import '../../onboarding/services/domain/provider_service_type.dart';
import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../../onboarding/requirements/options/domain/provider_selected_option.dart';
import '../domain/sub_service_rules.dart';
import 'service_providers.dart';

final class ServiceDetailState {
  ServiceDetailState({
    required this.service,
    required this.schema,
    required Set<int> selected,
    required this.experience,
    this.assignment,
    this.busy = false,
    this.saved = false,
    this.failure,
    this.inconsistent = false,
  }) : selected = Set.unmodifiable(selected);
  final ProviderServiceType service;
  final ProviderOnboardingSchema schema;
  final Set<int> selected;
  final String experience;
  final ProviderServiceAssignment? assignment;
  final bool busy, saved, inconsistent;
  final AppFailure? failure;
  String? get validation => inconsistent
      ? 'Some saved sub-services are no longer available. Retry to reload your service.'
      : validateSubServices(schema, selected) ??
            ProviderServiceInput.validateExperience(experience);
  ServiceDetailState copy({
    Set<int>? selected,
    String? experience,
    ProviderServiceAssignment? assignment,
    bool busy = false,
    bool saved = false,
    AppFailure? failure,
  }) => ServiceDetailState(
    service: service,
    schema: schema,
    selected: selected ?? this.selected,
    experience: experience ?? this.experience,
    assignment: assignment ?? this.assignment,
    busy: busy,
    saved: saved,
    failure: failure,
    inconsistent: inconsistent,
  );
}

final serviceDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ServiceDetailController, Result<ServiceDetailState>, int>(
      ServiceDetailController.new,
      dependencies: [
        providerServiceCatalogProvider,
        providerAssignmentsProvider,
        serviceSchemaProvider,
        providerServiceRepositoryProvider,
        providerOptionsRepositoryProvider,
        providerCompletionControllerProvider,
      ],
    );

final class ServiceDetailController
    extends AsyncNotifier<Result<ServiceDetailState>> {
  ServiceDetailController(this.serviceTypeId);
  final int serviceTypeId;
  int _generation = 0;
  @override
  Future<Result<ServiceDetailState>> build() async {
    _generation++;
    try {
      final catalog = await ref.watch(providerServiceCatalogProvider.future);
      final schema = await ref.watch(
        serviceSchemaProvider(serviceTypeId).future,
      );
      final assignments = await ref.watch(providerAssignmentsProvider.future);
      if (!ref.mounted ||
          catalog is! Success<List<ProviderServiceType>> ||
          schema is! Success<ProviderOnboardingSchema> ||
          assignments is! Success<List<ProviderServiceAssignment>>) {
        return _failure();
      }
      final service = catalog.value
          .where((s) => s.id == serviceTypeId)
          .firstOrNull;
      if (service == null || schema.value.serviceTypeId != serviceTypeId) {
        return _failure();
      }
      final assignment = assignments.value
          .where((a) => a.providerTypeId == serviceTypeId)
          .firstOrNull;
      Set<int> ids = {};
      if (assignment != null) {
        final selected = await ref
            .watch(providerOptionsRepositoryProvider)
            .loadSelections(assignment.assignmentId);
        if (selected is! Success<List<ProviderSelectedOption>>) {
          return _failure();
        }
        ids = selected.value.map((s) => s.optionId).toSet();
      }
      final valid = schema.value.options.map((o) => o.optionId).toSet();
      return Success(
        ServiceDetailState(
          service: service,
          schema: schema.value,
          selected: ids.intersection(valid),
          experience: assignment?.experienceYears.toString() ?? '',
          assignment: assignment,
          inconsistent: !valid.containsAll(ids),
        ),
      );
    } catch (_) {
      return _failure();
    }
  }

  Failure<ServiceDetailState> _failure() => const Failure(
    AppFailure(
      message: 'Unable to load this service. Please try again.',
      code: 'SERVICE_DETAIL_LOAD_FAILED',
    ),
  );
  void toggle(int id) {
    final result = state.asData?.value;
    if (result is! Success<ServiceDetailState> ||
        result.value.busy ||
        result.value.inconsistent ||
        !result.value.schema.options.any((o) => o.optionId == id)) {
      return;
    }
    final ids = Set<int>.of(result.value.selected);
    if (!ids.remove(id)) ids.add(id);
    state = AsyncData(Success(result.value.copy(selected: ids)));
  }

  void experience(String text) {
    final result = state.asData?.value;
    if (result is! Success<ServiceDetailState> ||
        result.value.busy ||
        result.value.assignment != null) {
      return;
    }
    state = AsyncData(Success(result.value.copy(experience: text)));
  }

  void retry() {
    if (state.isLoading) return;
    final container = ref.container;
    ref.read(providerServiceCatalogProvider.notifier).reload();
    container.invalidate(serviceSchemaProvider(serviceTypeId));
    container.invalidate(providerAssignmentsProvider);
    container.invalidate(serviceDetailControllerProvider(serviceTypeId));
  }

  Future<void> continueSetup() async {
    final result = state.asData?.value;
    if (result is! Success<ServiceDetailState>) return;
    var current = result.value;
    if (current.busy || current.saved || current.validation != null) return;
    final generation = _generation, container = ref.container;
    final services = ref.read(providerServiceRepositoryProvider),
        options = ref.read(providerOptionsRepositoryProvider);
    final completion = ref.read(providerCompletionControllerProvider.notifier);
    state = AsyncData(Success(current.copy(busy: true)));
    try {
      if (current.assignment == null) {
        final recovered = await services.loadAssignments();
        if (!ref.mounted || generation != _generation) return;
        if (recovered is! Success<List<ProviderServiceAssignment>>) {
          state = AsyncData(
            Success(
              current.copy(
                failure: const AppFailure(
                  message: 'Unable to check existing services. Please retry.',
                ),
              ),
            ),
          );
          return;
        }
        var assignment = recovered.value
            .where((a) => a.providerTypeId == serviceTypeId)
            .firstOrNull;
        if (assignment == null) {
          final created = await services.addService(
            ProviderServiceInput(
              providerTypeId: serviceTypeId,
              experienceYears: ProviderServiceInput.parseExperience(
                current.experience,
              )!,
            ),
          );
          if (!ref.mounted || generation != _generation) return;
          if (created is Failure<ProviderServiceAssignment>) {
            state = AsyncData(
              Success(
                current.copy(
                  failure: AppFailure(
                    message: created.failure.message,
                    code: created.failure.code,
                  ),
                ),
              ),
            );
            return;
          }
          assignment = (created as Success<ProviderServiceAssignment>).value;
        }
        if (assignment.providerTypeId != serviceTypeId) {
          throw const FormatException('Mismatched assignment');
        }
        current = current.copy(
          assignment: assignment,
          experience: assignment.experienceYears.toString(),
        );
        state = AsyncData(Success(current.copy(busy: true)));
      }
      final ids = current.selected.toList()..sort();
      final saved = await options.saveSelections(
        current.assignment!.assignmentId,
        ids,
      );
      if (!ref.mounted || generation != _generation) return;
      if (saved is Failure<void>) {
        state = AsyncData(
          Success(
            current.copy(
              failure: AppFailure(
                message: saved.failure.message,
                code: saved.failure.code,
              ),
            ),
          ),
        );
        return;
      }
      state = AsyncData(Success(current.copy(saved: true)));
      completion.reload();
      container.invalidate(providerAssignmentsProvider);
      container.invalidate(serviceSchemaProvider(serviceTypeId));
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          Success(
            current.copy(
              failure: const AppFailure(
                message: 'Unable to save your service. Please retry.',
              ),
            ),
          ),
        );
      }
    }
  }
}

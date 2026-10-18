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
import '../documents/documents_controller.dart'
    show documentsRepositoryProvider;
import '../documents/document_models.dart';
import 'service_providers.dart';
import 'service_draft_store.dart';

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
    this.registered = const [],
    this.incompleteRegistrationIds = const {},
  }) : selected = Set.unmodifiable(selected);
  final ProviderServiceType service;
  final ProviderOnboardingSchema schema;
  final Set<int> selected;
  final String experience;
  final ProviderServiceAssignment? assignment;
  final bool busy, saved, inconsistent;
  final AppFailure? failure;
  final List<ProviderSelectedOption> registered;
  final Set<int> incompleteRegistrationIds;
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
    registered: registered,
    incompleteRegistrationIds: incompleteRegistrationIds,
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
        serviceDraftStoreProvider,
        documentsRepositoryProvider,
        clockProvider,
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
      List<ProviderSelectedOption> registered = [];
      if (assignment != null) {
        final selected = await ref
            .watch(providerOptionsRepositoryProvider)
            .loadSelections(assignment.assignmentId);
        if (selected is! Success<List<ProviderSelectedOption>>) {
          return _failure();
        }
        ids = selected.value.map((s) => s.optionId).toSet();
        registered = selected.value;
      }
      final incompleteRegistrationIds = <int>{};
      final pendingOptions = registered.where(
        (option) =>
            option.verificationStatus == 'PENDING' &&
            option.providerStatus != 'INACTIVE' &&
            option.adminStatus != 'INACTIVE',
      );
      if (pendingOptions.isNotEmpty) {
        try {
          final documents = ref.watch(documentsRepositoryProvider);
          final results = await Future.wait([
            documents.requirements(serviceTypeId),
            documents.documents(),
          ]);
          if (!ref.mounted) return _failure();
          final requirements = results[0];
          final uploads = results[1];
          // Only known missing documents imply an unfinished registration.
          // Failed refreshes must not relabel existing review/approval states.
          if (requirements is Success<List<DocumentRequirement>> &&
              uploads is Success<List<ProviderDocument>>) {
            final now = ref.read(clockProvider)();
            for (final option in pendingOptions) {
              if (requirements.value
                  .where(
                    (requirement) =>
                        requirement.required &&
                        (requirement.optionId == null ||
                            requirement.optionId == option.optionId),
                  )
                  .any(
                    (requirement) => !uploads.value.any(
                      (document) =>
                          document.typeId == requirement.id &&
                          [
                            'Approved',
                            'Pending approval',
                          ].contains(document.status(now)),
                    ),
                  )) {
                incompleteRegistrationIds.add(option.optionId);
              }
            }
          }
        } catch (_) {
          // Document availability must not hide the existing service overview.
        }
      }
      final valid = schema.value.options.map((o) => o.optionId).toSet();
      final draft = await ref
          .read(serviceDraftStoreProvider)
          .read(serviceTypeId);
      final draftIds = (draft?['selected'] as List?)?.whereType<int>().toSet();
      return Success(
        ServiceDetailState(
          service: service,
          schema: schema.value,
          selected: {...ids, ...?draftIds}.intersection(valid),
          experience:
              assignment?.experienceYears.toString() ??
              (draft?['experience'] as String? ?? ''),
          registered: registered,
          incompleteRegistrationIds: Set.unmodifiable(
            incompleteRegistrationIds,
          ),
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
    _saveDraft();
  }

  void experience(String text) {
    final result = state.asData?.value;
    if (result is! Success<ServiceDetailState> ||
        result.value.busy ||
        result.value.assignment != null) {
      return;
    }
    state = AsyncData(Success(result.value.copy(experience: text)));
    _saveDraft();
  }

  void _saveDraft() {
    final result = state.asData?.value;
    if (result is! Success<ServiceDetailState>) return;
    final store = ref.read(serviceDraftStoreProvider);
    store
        .write(serviceTypeId, result.value.selected, result.value.experience)
        .catchError((Object _) {
          if (ref.mounted) {
            final latest = state.asData?.value;
            if (latest is Success<ServiceDetailState>) {
              state = AsyncData(
                Success(
                  latest.value.copy(
                    failure: const AppFailure(
                      message: 'Unable to save progress on this device. Please try again.',
                    ),
                  ),
                ),
              );
            }
          }
        });
  }

  void retry() {
    if (state.isLoading) return;
    final container = ref.container;
    ref.read(providerServiceCatalogProvider.notifier).reload();
    container.invalidate(serviceSchemaProvider(serviceTypeId));
    container.invalidate(providerAssignmentsProvider);
    container.invalidate(serviceDetailControllerProvider(serviceTypeId));
  }

  Future<bool> continueSetup() async {
    final result = state.asData?.value;
    if (result is! Success<ServiceDetailState>) return false;
    var current = result.value;
    if (current.saved) return true;
    if (current.busy || current.validation != null) {
      return false;
    }
    final generation = _generation, container = ref.container;
    final services = ref.read(providerServiceRepositoryProvider),
        options = ref.read(providerOptionsRepositoryProvider);
    final completion = ref.read(providerCompletionControllerProvider.notifier);
    state = AsyncData(Success(current.copy(busy: true)));
    try {
      if (current.assignment == null) {
        final recovered = await services.loadAssignments();
        if (!ref.mounted || generation != _generation) return false;
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
          return false;
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
          if (!ref.mounted || generation != _generation) return false;
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
            return false;
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
      if (!ref.mounted || generation != _generation) return false;
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
        return false;
      }
      await ref.read(serviceDraftStoreProvider).clear(serviceTypeId);
      if (!ref.mounted || generation != _generation) return false;
      state = AsyncData(Success(current.copy(saved: true)));
      completion.reload();
      container.invalidate(providerAssignmentsProvider);
      container.invalidate(serviceSchemaProvider(serviceTypeId));
      return true;
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
    return false;
  }
}

import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../../onboarding/domain/provider_completion.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../../onboarding/requirements/domain/provider_requirement_section.dart';
import '../../onboarding/requirements/options/domain/provider_selected_option.dart';
import '../domain/sub_service_rules.dart';
import '../domain/provider_service_status.dart';
import 'service_providers.dart';

final class ServiceSetupData {
  ServiceSetupData(
    this.assignment,
    this.completion,
    this.serviceCompletion,
    this.schema,
    Set<int> selected,
  ) : selected = Set.unmodifiable(selected);
  final ProviderServiceAssignment assignment;
  final ProviderCompletion completion;
  final ProviderServiceCompletion serviceCompletion;
  final ProviderOnboardingSchema schema;
  final Set<int> selected;
  bool get selectionValid => validateSubServices(schema, selected) == null;
  ProviderServiceStatus? get status => productServiceStatus(
    assignment,
    serviceCompletion,
    setupComplete: editableSetupComplete,
  );
  bool get editableSetupComplete =>
      completion.profileCompleted &&
      completion.marketSelected &&
      selectionValid &&
      (!schema.serviceSetup.optionsRequired ||
          serviceCompletion.optionsCompleted) &&
      rows
          .where(
            (row) =>
                row.level != ProviderRequirementLevel.optional &&
                (row.section != ProviderRequirementSection.additional ||
                    fields.any((field) => field.required)),
          )
          .every((row) => row.completed);
  List<ProviderRequirementField> get fields => List.unmodifiable([
    ...schema.commonFields,
    ...schema.options
        .where((o) => selected.contains(o.optionId))
        .expand((o) => o.fields),
  ]);
  List<ProviderRequirementRow> get rows {
    final filtered = ProviderOnboardingSchema(
      serviceTypeId: schema.serviceTypeId,
      serviceName: schema.serviceName,
      serviceSetup: schema.serviceSetup,
      commonFields: schema.commonFields,
      options: schema.options
          .where((o) => selected.contains(o.optionId))
          .toList(),
    );
    return List.unmodifiable(
      requirementRows(filtered, serviceCompletion).where(
        (r) =>
            r.section != ProviderRequirementSection.options &&
            (r.section != ProviderRequirementSection.locations ||
                selected.isNotEmpty),
      ),
    );
  }
}

final serviceSetupControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ServiceSetupController, Result<ServiceSetupData>, int>(
      ServiceSetupController.new,
      dependencies: [
        providerAssignmentsProvider,
        providerCompletionControllerProvider,
        serviceSchemaProvider,
        providerOptionsRepositoryProvider,
      ],
    );

final class ServiceSetupController
    extends AsyncNotifier<Result<ServiceSetupData>> {
  ServiceSetupController(this.serviceTypeId);
  final int serviceTypeId;
  @override
  Future<Result<ServiceSetupData>> build() async {
    try {
      final assignments = await ref.watch(providerAssignmentsProvider.future);
      final completion = await ref.watch(
        providerCompletionControllerProvider.future,
      );
      final schema = await ref.watch(
        serviceSchemaProvider(serviceTypeId).future,
      );
      if (!ref.mounted ||
          assignments is! Success<List<ProviderServiceAssignment>> ||
          completion is! Success<ProviderCompletion> ||
          schema is! Success<ProviderOnboardingSchema>) {
        return _failure();
      }
      final a = assignments.value
          .where((a) => a.providerTypeId == serviceTypeId)
          .firstOrNull;
      final c = completion.value.services
          .where(
            (c) =>
                c.serviceTypeId == serviceTypeId &&
                c.assignmentId == a?.assignmentId,
          )
          .firstOrNull;
      if (a == null ||
          c == null ||
          schema.value.serviceTypeId != serviceTypeId) {
        return _failure();
      }
      final options = await ref
          .watch(providerOptionsRepositoryProvider)
          .loadSelections(a.assignmentId);
      if (options is! Success<List<ProviderSelectedOption>>) return _failure();
      return Success(
        ServiceSetupData(
          a,
          completion.value,
          c,
          schema.value,
          options.value.map((o) => o.optionId).toSet(),
        ),
      );
    } catch (_) {
      return _failure();
    }
  }

  Failure<ServiceSetupData> _failure() => const Failure(
    AppFailure(
      message: 'Unable to load this service setup. Please retry.',
      code: 'SERVICE_SETUP_LOAD_FAILED',
    ),
  );
  void refresh() {
    if (state.isLoading) return;
    final container = ref.container;
    ref.read(providerCompletionControllerProvider.notifier).reload();
    container.invalidate(providerAssignmentsProvider);
    container.invalidate(serviceSchemaProvider(serviceTypeId));
    container.invalidate(serviceSetupControllerProvider(serviceTypeId));
  }
}

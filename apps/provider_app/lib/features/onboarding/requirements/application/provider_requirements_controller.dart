import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_providers.dart';
import '../../application/provider_completion_controller.dart';
import '../../domain/provider_completion.dart';
import '../domain/provider_onboarding_schema.dart';
import '../domain/provider_requirement_section.dart';

final class ProviderRequirementsOverview {
  ProviderRequirementsOverview(
    this.completion,
    List<ProviderServiceCompletion> assignments,
    this.selected,
    this.schema,
  ) : assignments = List.unmodifiable(assignments);
  final ProviderCompletion completion;
  final List<ProviderServiceCompletion> assignments;
  final ProviderServiceCompletion selected;
  final ProviderOnboardingSchema schema;
  List<ProviderRequirementRow> get rows => requirementRows(schema, selected);
}

// Selection is kept in this controller only; authoritative identity always comes from completion.
final providerRequirementsControllerProvider =
    AsyncNotifierProvider<
      ProviderRequirementsController,
      Result<ProviderRequirementsOverview>
    >(
      ProviderRequirementsController.new,
      dependencies: [
        providerCompletionControllerProvider,
        providerSchemaRepositoryProvider,
      ],
    );

final class ProviderRequirementsController
    extends AsyncNotifier<Result<ProviderRequirementsOverview>> {
  int? _selectedId;
  @override
  Future<Result<ProviderRequirementsOverview>> build() async {
    try {
      final result = await ref.watch(
        providerCompletionControllerProvider.future,
      );
      if (!ref.mounted) return _failure();
      if (result is! Success<ProviderCompletion>) return _failure();
      final c = result.value;
      final assignments = c.services.where(serviceNeedsWork).toList()
        ..sort((a, b) => a.assignmentId.compareTo(b.assignmentId));
      if (assignments.isEmpty) {
        return const Failure(
          AppFailure(
            message: 'No service assignments need setup. Refresh your account setup to continue.',
            code: 'REQUIREMENTS_EMPTY',
          ),
        );
      }
      final selected =
          assignments.where((s) => s.assignmentId == _selectedId).firstOrNull ??
          assignments.first;
      _selectedId = selected.assignmentId;
      final schema = await ref
          .watch(providerSchemaRepositoryProvider)
          .loadSchema(selected.serviceTypeId);
      if (schema is Failure<ProviderOnboardingSchema>) {
        return Failure(
          AppFailure(
            message: schema.failure.message,
            code: schema.failure.code,
          ),
        );
      }
      if (schema is! Success<ProviderOnboardingSchema>) return _failure();
      return Success(
        ProviderRequirementsOverview(c, assignments, selected, schema.value),
      );
    } catch (_) {
      return _failure();
    }
  }

  Result<ProviderRequirementsOverview> _failure() => const Failure(
    AppFailure(
      message: 'Unable to load service requirements. Please try again.',
      code: 'REQUIREMENTS_LOAD_FAILED',
    ),
  );
  void select(int id) {
    final current = state.asData?.value;
    if (state.isLoading ||
        current is! Success<ProviderRequirementsOverview> ||
        current.value.selected.assignmentId == id ||
        !current.value.assignments.any((s) => s.assignmentId == id)) {
      return;
    }
    _selectedId = id;
    ref.invalidateSelf();
  }

  /// Reload completion and schema; concurrent calls share the active request.
  void refresh() {
    if (state.isLoading) return;
    ref.read(providerCompletionControllerProvider.notifier).reload();
    ref.invalidateSelf();
  }

  /// Also refresh the saved service schema when completion changes the next step
  /// or chooses a different assignment. Persistence success is never undone by
  /// a refresh error; the gateway/overview owns the retry state.
  Future<void> refreshAfterOptionsSave(int serviceTypeId) async {
    final container = ref.container;
    final repository = ref.read(providerSchemaRepositoryProvider);
    refresh();
    try {
      final updated = await container.read(
        providerRequirementsControllerProvider.future,
      );
      if (updated is Success<ProviderRequirementsOverview> &&
          updated.value.schema.serviceTypeId == serviceTypeId) {
        return;
      }
      await repository.loadSchema(serviceTypeId);
    } catch (_) {
      // The gateway/overview exposes safe retry states; a saved set stays saved.
    }
  }
}

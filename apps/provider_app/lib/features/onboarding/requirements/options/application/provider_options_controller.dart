import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/providers/app_providers.dart';
import '../../application/provider_requirements_controller.dart';
import '../../domain/provider_requirement_section.dart';
import '../domain/provider_selected_option.dart';

final class ProviderOptionsContext {
  const ProviderOptionsContext(this.assignmentId, this.serviceTypeId);
  final int? assignmentId, serviceTypeId;
  @override
  bool operator ==(Object other) =>
      other is ProviderOptionsContext &&
      other.assignmentId == assignmentId &&
      other.serviceTypeId == serviceTypeId;
  @override
  int get hashCode => Object.hash(assignmentId, serviceTypeId);
}

final class ProviderOptionsState {
  ProviderOptionsState(
    this.overview,
    Set<int> selected, {
    this.saving = false,
    this.saved = false,
    this.failure,
    this.inconsistent = false,
  }) : selected = Set.unmodifiable(selected);
  final ProviderRequirementsOverview overview;
  final Set<int> selected;
  final bool saving, saved, inconsistent;
  final AppFailure? failure;
  bool get rulesUnavailable =>
      overview.schema.serviceSetup.optionsRequired &&
      overview.schema.serviceSetup.minimumOptionSelections == null;
  String? get validation {
    final setup = overview.schema.serviceSetup;
    if (inconsistent) {
      return 'Some saved options are no longer available. Retry to reload your service options.';
    }
    if (setup.optionsRequired && setup.minimumOptionSelections == null) {
      return 'Selection rules are unavailable. Please retry.';
    }
    final min = setup.minimumOptionSelections;
    if (min != null && selected.length < min) {
      return 'Select at least $min option${min == 1 ? '' : 's'}.';
    }
    final max = setup.maximumOptionSelections;
    if (max != null && selected.length > max) {
      return 'Select no more than $max option${max == 1 ? '' : 's'}.';
    }
    return null;
  }
}

final providerOptionsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      ProviderOptionsController,
      Result<ProviderOptionsState>,
      ProviderOptionsContext
    >(
      ProviderOptionsController.new,
      dependencies: [
        providerRequirementsControllerProvider,
        providerOptionsRepositoryProvider,
      ],
    );

final class ProviderOptionsController
    extends AsyncNotifier<Result<ProviderOptionsState>> {
  ProviderOptionsController(this.context);
  final ProviderOptionsContext context;
  int _generation = 0;
  @override
  Future<Result<ProviderOptionsState>> build() async {
    _generation++;
    try {
      var result = await ref.watch(
        providerRequirementsControllerProvider.future,
      );
      if (!ref.mounted || result is! Success<ProviderRequirementsOverview>) {
        return _failure();
      }
      final target = result.value.assignments
          .where(
            (s) =>
                s.assignmentId == context.assignmentId &&
                s.serviceTypeId == context.serviceTypeId,
          )
          .firstOrNull;
      if (target == null) return _failure('Section unavailable');
      if (target.assignmentId != result.value.selected.assignmentId) {
        ref
            .read(providerRequirementsControllerProvider.notifier)
            .select(target.assignmentId);
        result = await ref.read<Future<Result<ProviderRequirementsOverview>>>(
          providerRequirementsControllerProvider.future,
        );
      }
      if (!ref.mounted || result is! Success<ProviderRequirementsOverview>) {
        return _failure();
      }
      final v = result.value;
      if (v.selected.assignmentId != context.assignmentId ||
          v.selected.serviceTypeId != context.serviceTypeId ||
          !v.rows.any((r) => r.section == ProviderRequirementSection.options)) {
        return _failure('Section unavailable');
      }
      final selections = await ref
          .watch(providerOptionsRepositoryProvider)
          .loadSelections(v.selected.assignmentId);
      if (selections is! Success<List<ProviderSelectedOption>>) {
        return _failure();
      }
      final ids = selections.value.map((v) => v.optionId).toSet();
      final valid = v.schema.options.map((o) => o.optionId).toSet();
      return Success(
        ProviderOptionsState(
          v,
          ids.intersection(valid),
          inconsistent: !valid.containsAll(ids),
        ),
      );
    } catch (_) {
      return _failure();
    }
  }

  Failure<ProviderOptionsState> _failure([
    String message = 'Unable to load service options. Please try again.',
  ]) => Failure(AppFailure(message: message, code: 'OPTIONS_LOAD_FAILED'));
  void toggle(int id) {
    final result = state.asData?.value;
    if (result is! Success<ProviderOptionsState>) return;
    final v = result.value;
    if (v.saving ||
        v.saved ||
        v.inconsistent ||
        !v.overview.schema.options.any((o) => o.optionId == id)) {
      return;
    }
    final ids = Set<int>.of(v.selected);
    if (!ids.remove(id)) ids.add(id);
    state = AsyncData(Success(ProviderOptionsState(v.overview, ids)));
  }

  void retry() {
    if (!state.isLoading) {
      ref.read(providerRequirementsControllerProvider.notifier).refresh();
      ref.invalidateSelf();
    }
  }

  Future<void> save() async {
    final result = state.asData?.value;
    if (result is! Success<ProviderOptionsState>) return;
    final v = result.value;
    if (v.saving ||
        v.saved ||
        v.inconsistent ||
        v.validation != null ||
        v.overview.schema.options.isEmpty) {
      return;
    }
    state = AsyncData(
      Success(ProviderOptionsState(v.overview, v.selected, saving: true)),
    );
    final generation = _generation;
    final refreshController = ref.read(
      providerRequirementsControllerProvider.notifier,
    );
    try {
      final ids = v.selected.toList()..sort();
      final response = await ref
          .read(providerOptionsRepositoryProvider)
          .saveSelections(v.overview.selected.assignmentId, ids);
      if (!ref.mounted || generation != _generation) return;
      if (response is Failure<void>) {
        state = AsyncData(
          Success(
            ProviderOptionsState(
              v.overview,
              v.selected,
              failure: AppFailure(
                message: response.failure.message,
                code: response.failure.code,
              ),
            ),
          ),
        );
        return;
      }
      state = AsyncData(
        Success(ProviderOptionsState(v.overview, v.selected, saved: true)),
      );
      await refreshController.refreshAfterOptionsSave(
        v.overview.selected.serviceTypeId,
      );
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          Success(
            ProviderOptionsState(
              v.overview,
              v.selected,
              failure: const AppFailure(
                message: 'Unable to save service options. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }
}

import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:provider_app/features/onboarding/requirements/options/domain/provider_options_repository.dart';
import 'package:provider_app/features/onboarding/requirements/options/domain/provider_selected_option.dart';

Map<String, dynamic> selectedOptionJson({int id = 12}) => {
  'providerOptionId': 100 + id,
  'optionId': id,
  'code': 'CODE',
  'name': 'Home care',
  'providerStatus': 'ACTIVE',
  'adminStatus': 'ACTIVE',
  'verificationStatus': 'PENDING',
  'reviewedBy': null,
  'reviewedAt': null,
  'reviewNote': null,
};

final class FakeOptionsRepository implements ProviderOptionsRepository {
  final List<int> loads = [];
  final List<({int assignmentId, List<int> ids})> saves = [];
  Result<List<ProviderSelectedOption>> selections = const Success([]);
  final selectionsByAssignment = <int, Result<List<ProviderSelectedOption>>>{};
  Result<void> saveResult = const Success(null);
  Completer<Result<List<ProviderSelectedOption>>>? pendingLoad;
  Completer<Result<void>>? pendingSave;
  void Function()? onSave;
  @override
  Future<Result<List<ProviderSelectedOption>>> loadSelections(int id) async {
    loads.add(id);
    return pendingLoad != null
        ? pendingLoad!.future
        : selectionsByAssignment[id] ?? selections;
  }

  @override
  Future<Result<void>> saveSelections(int id, List<int> ids) async {
    saves.add((assignmentId: id, ids: List.of(ids)));
    onSave?.call();
    return pendingSave != null ? pendingSave!.future : saveResult;
  }
}

import 'package:bthere_common/bthere_common.dart';

import 'provider_selected_option.dart';

abstract interface class ProviderOptionsRepository {
  Future<Result<List<ProviderSelectedOption>>> loadSelections(int assignmentId);
  Future<Result<void>> saveSelections(int assignmentId, List<int> optionIds);
}

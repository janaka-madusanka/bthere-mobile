import 'package:bthere_common/bthere_common.dart';

import 'provider_completion.dart';

abstract interface class ProviderCompletionRepository {
  Future<Result<ProviderCompletion>> loadCompletion();
}

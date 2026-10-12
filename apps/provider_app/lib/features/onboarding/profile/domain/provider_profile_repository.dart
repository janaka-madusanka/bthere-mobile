import 'package:bthere_common/bthere_common.dart';

import 'provider_profile_input.dart';

abstract interface class ProviderProfileRepository {
  Future<Result<void>> updateProfile(ProviderProfileInput input);
}

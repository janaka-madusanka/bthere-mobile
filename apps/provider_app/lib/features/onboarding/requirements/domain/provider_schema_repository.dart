import 'package:bthere_common/bthere_common.dart';

import 'provider_onboarding_schema.dart';

abstract interface class ProviderSchemaRepository {
  Future<Result<ProviderOnboardingSchema>> loadSchema(int serviceTypeId);
}

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';

import '../domain/provider_onboarding_schema.dart';
import '../domain/provider_schema_repository.dart';
import 'provider_schema_remote_data_source.dart';
import 'provider_schema_response.dart';

final class ProviderSchemaRepositoryImpl implements ProviderSchemaRepository {
  const ProviderSchemaRepositoryImpl(this.remote);
  final ProviderSchemaRemoteDataSource remote;
  @override
  Future<Result<ProviderOnboardingSchema>> loadSchema(int serviceTypeId) async {
    try {
      integer(serviceTypeId, positive: true);
      final schema = parseProviderSchema(
        await remote.loadSchema(serviceTypeId),
        serviceTypeId,
      );
      return Success(
        applyPublicOptions(schema, await remote.loadOptions(serviceTypeId)),
      );
    } on NetworkException catch (e) {
      return Failure(e.toAppFailure());
    } on UnsupportedRequirementMetadata {
      return const Failure(
        AppFailure(
          message: 'This service uses unsupported requirement settings. Please try again.',
          code: 'SCHEMA_UNSUPPORTED_METADATA',
        ),
      );
    } catch (_) {
      return const Failure(
        AppFailure(
          message: 'Unable to load service requirements. Please try again.',
          code: 'SCHEMA_INVALID_RESPONSE',
        ),
      );
    }
  }
}

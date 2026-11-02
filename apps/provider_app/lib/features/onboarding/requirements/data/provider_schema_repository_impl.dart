import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';

import '../domain/provider_onboarding_schema.dart';
import '../domain/provider_schema_repository.dart';
import 'provider_schema_remote_data_source.dart';
import 'provider_schema_response.dart';

final class ProviderSchemaRepositoryImpl implements ProviderSchemaRepository {
  const ProviderSchemaRepositoryImpl(this.remote, {this.diagnosticLogger});
  final ProviderSchemaRemoteDataSource remote;
  final void Function(String)? diagnosticLogger;
  @override
  Future<Result<ProviderOnboardingSchema>> loadSchema(int serviceTypeId) async {
    try {
      integer(serviceTypeId, positive: true);
      final raw = await remote.loadSchema(serviceTypeId);
      final schema = schemaValue(
        'onboarding-schema',
        () => parseProviderSchema(raw, serviceTypeId),
      );
      final options = await remote.loadOptions(serviceTypeId);
      return Success(
        schemaValue(
          'public-options',
          () => applyPublicOptions(schema, options),
        ),
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
    } on InvalidSchemaValue catch (error) {
      diagnosticLogger?.call(
        '[ProviderSchema] serviceTypeId=$serviceTypeId invalidPath=${error.path}',
      );
      return const Failure(
        AppFailure(
          message: 'Unable to load service requirements. Please try again.',
          code: 'SCHEMA_INVALID_RESPONSE',
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

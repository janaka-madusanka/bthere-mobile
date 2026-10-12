import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';

import '../domain/provider_profile_input.dart';
import '../domain/provider_profile_repository.dart';
import 'provider_profile_remote_data_source.dart';

final class ProviderProfileRepositoryImpl implements ProviderProfileRepository {
  const ProviderProfileRepositoryImpl(this._remote);
  final ProviderProfileRemoteDataSource _remote;
  @override
  Future<Result<void>> updateProfile(ProviderProfileInput input) async {
    try {
      await _remote.updateProfile(input);
      return const Success(null);
    } on NetworkException catch (error) {
      if (error.backendCode == 'VALIDATION_ERROR' ||
          error.message == 'Validation failed') {
        return const Failure(
          AppFailure(
            message: 'Please check your profile details and try again.',
            code: 'VALIDATION_ERROR',
          ),
        );
      }
      return Failure(error.toAppFailure());
    } catch (_) {
      return const Failure(
        AppFailure(
          message: 'Unable to save your profile. Please try again.',
          code: 'PROFILE_UPDATE_FAILED',
        ),
      );
    }
  }
}

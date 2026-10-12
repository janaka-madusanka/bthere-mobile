import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';

import '../domain/provider_completion.dart';
import '../domain/provider_completion_repository.dart';
import 'provider_completion_remote_data_source.dart';
import 'provider_completion_response.dart';

final class ProviderCompletionRepositoryImpl
    implements ProviderCompletionRepository {
  const ProviderCompletionRepositoryImpl(this._remote);
  final ProviderCompletionRemoteDataSource _remote;
  @override
  Future<Result<ProviderCompletion>> loadCompletion() async {
    try {
      return Success(parseProviderCompletion(await _remote.loadCompletion()));
    } on NetworkException catch (error) {
      return Failure(error.toAppFailure());
    } on UnsupportedOnboardingStep {
      return const Failure(
        AppFailure(
          message: 'This onboarding step is not supported yet. Please try again later.',
          code: 'ONBOARDING_UNSUPPORTED_STEP',
        ),
      );
    } on FormatException {
      return const Failure(
        AppFailure(
          message:
              'Unable to read your account setup status. Please try again.',
          code: 'ONBOARDING_INVALID_RESPONSE',
        ),
      );
    } catch (_) {
      return const Failure(
        AppFailure(
          message: 'Unable to check your account setup. Please try again.',
          code: 'ONBOARDING_OPERATION_FAILED',
        ),
      );
    }
  }
}

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';

import '../domain/provider_selected_option.dart';
import '../domain/provider_options_repository.dart';
import 'provider_options_remote_data_source.dart';
import 'provider_options_response.dart';
import '../../../../services/data/registration_repository.dart';
import '../../../../services/domain/service_registration.dart';

final class _SelectionFailure implements Exception {
  const _SelectionFailure(this.failure);
  final AppFailure failure;
}

final class ProviderOptionsRepositoryImpl implements ProviderOptionsRepository {
  const ProviderOptionsRepositoryImpl(this.remote);
  final ProviderOptionsRemoteDataSource remote;
  @override
  Future<Result<List<ProviderSelectedOption>>> loadSelections(
    int assignmentId,
  ) => _request(() async {
    if (assignmentId <= 0) throw const FormatException('Invalid assignment');
    return parseProviderOptions(await remote.loadSelections(assignmentId));
  });
  @override
  Future<Result<void>> saveSelections(int assignmentId, List<int> optionIds) =>
      _request(() async {
        if (assignmentId <= 0 ||
            optionIds.any((id) => id <= 0) ||
            optionIds.toSet().length != optionIds.length) {
          throw const FormatException('Invalid options');
        }
        final registrations = RegistrationRepository(remote.client);
        for (final optionId in optionIds) {
          final result = await registrations.sharedRegistration(optionId);
          if (result is Failure<SharedOptionRegistration?>) {
            throw _SelectionFailure(result.failure);
          }
          final source = (result as Success<SharedOptionRegistration?>).value;
          if (source != null && source.assignmentId != assignmentId) {
            throw const _SelectionFailure(
              AppFailure(
                message: 'This sub-service is already registered. Open its existing service to manage it.',
                code: 'SHARED_OPTION_ALREADY_REGISTERED',
              ),
            );
          }
        }
        await remote.saveSelections(assignmentId, optionIds);
      });
  Future<Result<T>> _request<T>(Future<T> Function() operation) async {
    try {
      return Success(await operation());
    } on _SelectionFailure catch (e) {
      return Failure(e.failure);
    } on NetworkException catch (e) {
      return Failure(e.toAppFailure());
    } catch (_) {
      return const Failure(
        AppFailure(
          message: 'Unable to update service options. Please try again.',
          code: 'OPTIONS_OPERATION_FAILED',
        ),
      );
    }
  }
}

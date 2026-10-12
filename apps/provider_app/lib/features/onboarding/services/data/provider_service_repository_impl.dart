import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';

import '../domain/provider_service_type.dart';
import '../domain/provider_service_assignment.dart';
import '../domain/provider_service_input.dart';
import '../domain/provider_service_repository.dart';
import 'provider_service_remote_data_source.dart';
import 'provider_service_response.dart';

final class ProviderServiceRepositoryImpl implements ProviderServiceRepository {
  const ProviderServiceRepositoryImpl(this._remote);
  final ProviderServiceRemoteDataSource _remote;
  @override
  Future<Result<List<ProviderServiceType>>> loadActiveServices() => _request(
    () async => parseActiveProviderServices(await _remote.loadServices()),
  );
  @override
  Future<Result<List<ProviderServiceAssignment>>> loadAssignments() => _request(
    () async =>
        parseProviderServiceAssignments(await _remote.loadAssignments()),
  );
  @override
  Future<Result<ProviderServiceAssignment>> addService(
    ProviderServiceInput input,
  ) {
    if (!input.isValid) {
      return Future.value(
        const Failure(
          AppFailure(
            message: 'Select a service and enter valid experience years.',
            code: 'SERVICE_INVALID_INPUT',
          ),
        ),
      );
    }
    return _request(() async {
      final assignment = parseProviderServiceAssignment(
        await _remote.addService(input),
      );
      if (assignment.providerTypeId != input.providerTypeId) {
        throw const FormatException('Mismatched service');
      }
      return assignment;
    });
  }

  Future<Result<T>> _request<T>(Future<T> Function() fetch) async {
    try {
      return Success(await fetch());
    } on NetworkException catch (error) {
      return Failure(error.toAppFailure());
    } on FormatException {
      return const Failure(
        AppFailure(
          message: 'Unable to read service setup data. Please try again.',
          code: 'SERVICE_INVALID_RESPONSE',
        ),
      );
    } catch (_) {
      return const Failure(
        AppFailure(
          message: 'Unable to complete service setup. Please try again.',
          code: 'SERVICE_OPERATION_FAILED',
        ),
      );
    }
  }
}

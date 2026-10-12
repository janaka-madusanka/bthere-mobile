import 'package:bthere_common/bthere_common.dart';

import 'provider_service_type.dart';
import 'provider_service_assignment.dart';
import 'provider_service_input.dart';

abstract interface class ProviderServiceRepository {
  Future<Result<List<ProviderServiceType>>> loadActiveServices();
  Future<Result<List<ProviderServiceAssignment>>> loadAssignments();
  Future<Result<ProviderServiceAssignment>> addService(
    ProviderServiceInput input,
  );
}

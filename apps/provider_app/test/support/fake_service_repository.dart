import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_repository.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_assignment.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_input.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';

Map<String, dynamic> serviceJson({
  int id = 3,
  String name = 'Home Nurse',
  String status = 'ACTIVE',
}) => {
  'id': id,
  'name': name,
  'description': 'Home nursing services',
  'iconUrl': null,
  'status': status,
};
Map<String, dynamic> assignmentJson({int typeId = 3}) => {
  'assignmentId': 14,
  'providerTypeId': typeId,
  'providerTypeName': 'Home Nurse',
  'experienceYears': 4.5,
  'status': 'ACTIVE',
  'providerStatus': 'ACTIVE',
  'adminStatus': 'ACTIVE',
  'verificationStatus': 'PENDING',
  'emergencyOverride': false,
  'emergencyOverrideReason': null,
  'emergencyOverrideExpiresAt': null,
  'requiredDocumentTypeIds': [1, 2],
  'missingDocumentTypeIds': [1, 2],
};

final class FakeServiceRepository implements ProviderServiceRepository {
  int loads = 0, submissions = 0, assignmentLoads = 0;
  Result<List<ProviderServiceAssignment>> assignments = const Success([]);
  Completer<Result<List<ProviderServiceAssignment>>>? pendingAssignments;
  @override
  Future<Result<List<ProviderServiceAssignment>>> loadAssignments() async {
    assignmentLoads++;
    return pendingAssignments == null
        ? assignments
        : pendingAssignments!.future;
  }

  ProviderServiceInput? input;
  Completer<Result<List<ProviderServiceType>>>? pendingLoad;
  Completer<Result<ProviderServiceAssignment>>? pendingSubmit;
  bool throwLoad = false, throwSubmit = false;
  Result<List<ProviderServiceType>> catalog = Success(
    parseActiveProviderServices([
      serviceJson(),
      serviceJson(id: 9, name: 'Other service'),
    ]),
  );
  Result<ProviderServiceAssignment>? submission;
  @override
  Future<Result<List<ProviderServiceType>>> loadActiveServices() async {
    loads++;
    if (throwLoad) throw StateError('private service exception');
    return pendingLoad == null ? catalog : pendingLoad!.future;
  }

  @override
  Future<Result<ProviderServiceAssignment>> addService(
    ProviderServiceInput value,
  ) async {
    submissions++;
    input = value;
    if (throwSubmit) throw StateError('private service exception');
    final result = pendingSubmit == null
        ? submission ??
              Success(
                parseProviderServiceAssignment(
                  assignmentJson(typeId: value.providerTypeId)
                    ..['experienceYears'] = value.experienceYears,
                ),
              )
        : await pendingSubmit!.future;
    if (result is Success<ProviderServiceAssignment>) {
      final existing = assignments is Success<List<ProviderServiceAssignment>>
          ? (assignments as Success<List<ProviderServiceAssignment>>).value
          : <ProviderServiceAssignment>[];
      assignments = Success([
        ...existing.where((a) => a.providerTypeId != value.providerTypeId),
        result.value,
      ]);
    }
    return result;
  }
}

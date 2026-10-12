import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/domain/provider_completion.dart';
import 'package:provider_app/features/onboarding/domain/provider_completion_repository.dart';

Map<String, dynamic> completionJson({String step = 'COMPLETED'}) => {
  'profileCompleted': true,
  'marketSelected': true,
  'serviceSelected': true,
  'allActiveServicesApproved': false,
  'completionPercentage': 75,
  'nextStep': step,
  'services': [
    {
      'assignmentId': 14,
      'serviceTypeId': 3,
      'serviceName': 'Home Nurse',
      'documentsCompleted': false,
      'skillsCompleted': true,
      'certificatesCompleted': false,
      'educationCompleted': true,
      'availabilityCompleted': true,
      'serviceAreasCompleted': true,
      'optionsCompleted': false,
      'customRequirementsCompleted': true,
      'verificationStatus': 'PENDING',
      'effectiveStatus': 'ACTIVE',
    },
  ],
};

final class FakeCompletionRepository implements ProviderCompletionRepository {
  int calls = 0;
  Completer<Result<ProviderCompletion>>? pending;
  Result<ProviderCompletion> result = Success(
    parseProviderCompletion(completionJson()),
  );
  @override
  Future<Result<ProviderCompletion>> loadCompletion() async {
    calls++;
    return pending == null ? result : pending!.future;
  }
}

import '../../onboarding/services/domain/provider_service_input.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../onboarding/domain/provider_completion.dart';

/// Atomic creation alternative to the existing supported section update APIs.
/// Uploads happen first; collections contain returned file keys, never bytes.
class ServiceRegistrationInput {
  const ServiceRegistrationInput({
    required this.service,
    required this.optionIds,
    required this.languages,
    this.skillIds = const [],
    this.documents = const [],
    this.certificates = const [],
    this.education = const [],
    this.availability,
    this.unavailableDates = const [],
    this.serviceAreas = const [],
    this.submissions = const [],
  });
  final ProviderServiceInput service;
  final List<int> optionIds, skillIds;
  final List<String> languages;
  final List<Map<String, dynamic>> documents,
      certificates,
      education,
      unavailableDates,
      serviceAreas,
      submissions;
  final Map<String, dynamic>? availability;
  Map<String, dynamic> toJson() {
    if (!service.isValid ||
        optionIds.any((id) => id <= 0) ||
        optionIds.toSet().length != optionIds.length ||
        skillIds.any((id) => id <= 0) ||
        languages.any((l) => !['SINHALA', 'ENGLISH', 'TAMIL'].contains(l))) {
      throw const FormatException('Invalid service registration');
    }
    final groups = <String>{};
    for (final area in serviceAreas) {
      if (!optionIds.contains(area['optionId']) ||
          ![
            'PROVIDER_TO_CUSTOMER',
            'CUSTOMER_TO_PROVIDER',
          ].contains(area['deliveryMode']) ||
          area['locations'] is! List ||
          (area['locations'] as List).isEmpty ||
          !groups.add('${area['optionId']}/${area['deliveryMode']}')) {
        throw const FormatException('Invalid service area group');
      }
    }
    return {
      'service': service.toJson(),
      'options': {'optionIds': optionIds},
      'languages': {'languages': languages},
      'skills': {'skillIds': skillIds},
      'documents': documents,
      'certificates': certificates,
      'education': education,
      if (availability != null) 'availability': availability,
      'unavailableDates': unavailableDates,
      'serviceAreas': serviceAreas,
      'requirements': {'submissions': submissions},
    };
  }
}

class ServiceRegistrationResult {
  const ServiceRegistrationResult({
    required this.assignment,
    required this.completion,
  });
  final ProviderServiceAssignment assignment;
  final ProviderCompletion completion;
}

class SharedOptionRegistration {
  const SharedOptionRegistration({
    required this.optionId,
    required this.providerOptionId,
    required this.assignmentId,
    required this.registrationServiceTypeId,
    required this.providerStatus,
    required this.adminStatus,
    required this.verificationStatus,
  });
  final int optionId, providerOptionId, assignmentId, registrationServiceTypeId;
  final String providerStatus, adminStatus, verificationStatus;
}

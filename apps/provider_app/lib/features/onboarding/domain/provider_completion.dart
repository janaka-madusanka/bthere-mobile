enum ProviderOnboardingStep {
  completeProfile('COMPLETE_PROFILE'),
  selectMarket('SELECT_MARKET'),
  selectService('SELECT_SERVICE'),
  completeServiceRequirements('COMPLETE_SERVICE_REQUIREMENTS'),
  awaitAdminApproval('AWAIT_ADMIN_APPROVAL'),
  completed('COMPLETED');

  const ProviderOnboardingStep(this.wireValue);
  final String wireValue;
}

final class ProviderCompletion {
  ProviderCompletion({
    required this.profileCompleted,
    required this.marketSelected,
    required this.serviceSelected,
    required this.allActiveServicesApproved,
    required this.completionPercentage,
    required this.nextStep,
    required List<ProviderServiceCompletion> services,
  }) : services = List.unmodifiable(services);
  final bool profileCompleted,
      marketSelected,
      serviceSelected,
      allActiveServicesApproved;
  final num completionPercentage;
  final ProviderOnboardingStep nextStep;
  final List<ProviderServiceCompletion> services;
}

final class ProviderServiceCompletion {
  const ProviderServiceCompletion({
    required this.assignmentId,
    required this.serviceTypeId,
    required this.serviceName,
    required this.documentsCompleted,
    required this.skillsCompleted,
    required this.certificatesCompleted,
    required this.educationCompleted,
    required this.availabilityCompleted,
    required this.serviceAreasCompleted,
    required this.optionsCompleted,
    required this.customRequirementsCompleted,
    required this.verificationStatus,
    required this.effectiveStatus,
  });
  final int assignmentId, serviceTypeId;
  final String serviceName, verificationStatus, effectiveStatus;
  final bool documentsCompleted,
      skillsCompleted,
      certificatesCompleted,
      educationCompleted,
      availabilityCompleted,
      serviceAreasCompleted,
      optionsCompleted,
      customRequirementsCompleted;
}

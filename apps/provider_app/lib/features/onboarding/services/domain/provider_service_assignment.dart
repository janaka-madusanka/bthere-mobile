final class ProviderServiceAssignment {
  ProviderServiceAssignment({
    required this.assignmentId,
    required this.providerTypeId,
    required this.providerTypeName,
    required this.experienceYears,
    required this.status,
    required this.providerStatus,
    required this.adminStatus,
    required this.verificationStatus,
    required this.emergencyOverride,
    this.rejectionReason,
    this.emergencyOverrideReason,
    this.emergencyOverrideExpiresAt,
    required List<int> requiredDocumentTypeIds,
    required List<int> missingDocumentTypeIds,
  }) : requiredDocumentTypeIds = List.unmodifiable(requiredDocumentTypeIds),
       missingDocumentTypeIds = List.unmodifiable(missingDocumentTypeIds);
  final int assignmentId, providerTypeId;
  final String providerTypeName,
      status,
      providerStatus,
      adminStatus,
      verificationStatus;
  final num experienceYears;
  final bool emergencyOverride;
  final String? emergencyOverrideReason, rejectionReason;
  final DateTime? emergencyOverrideExpiresAt;
  final List<int> requiredDocumentTypeIds, missingDocumentTypeIds;
}

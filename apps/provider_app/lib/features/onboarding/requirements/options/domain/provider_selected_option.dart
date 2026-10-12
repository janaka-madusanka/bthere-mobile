final class ProviderSelectedOption {
  const ProviderSelectedOption({
    required this.providerOptionId,
    required this.optionId,
    required this.code,
    required this.name,
    required this.providerStatus,
    required this.adminStatus,
    required this.verificationStatus,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
  });
  final int providerOptionId, optionId;
  final String code, name, providerStatus, adminStatus, verificationStatus;
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;
}

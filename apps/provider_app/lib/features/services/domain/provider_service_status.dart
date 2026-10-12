import '../../onboarding/domain/provider_completion.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';

enum ProviderServiceStatus {
  available('Available'),
  setupRequired('Setup required'),
  pendingApproval('Pending approval'),
  approved('Approved'),
  rejected('Rejected'),
  inactive('Inactive');

  const ProviderServiceStatus(this.label);
  final String label;
}

bool allServiceFlagsComplete(ProviderServiceCompletion c) =>
    c.documentsCompleted &&
    c.skillsCompleted &&
    c.certificatesCompleted &&
    c.educationCompleted &&
    c.availabilityCompleted &&
    c.serviceAreasCompleted &&
    c.optionsCompleted &&
    c.customRequirementsCompleted;
ProviderServiceStatus? productServiceStatus(
  ProviderServiceAssignment? assignment,
  ProviderServiceCompletion? completion, {
  bool progressKnown = true,
  bool? setupComplete,
}) {
  if (assignment == null && completion == null) {
    return progressKnown ? ProviderServiceStatus.available : null;
  }
  final states = [
    assignment?.status,
    assignment?.providerStatus,
    assignment?.adminStatus,
    completion?.effectiveStatus,
  ];
  if (states.contains('INACTIVE')) return ProviderServiceStatus.inactive;
  if (states.contains('REJECTED') ||
      assignment?.verificationStatus == 'REJECTED' ||
      completion?.verificationStatus == 'REJECTED') {
    return ProviderServiceStatus.rejected;
  }
  if (completion?.verificationStatus == 'APPROVED' ||
      assignment?.verificationStatus == 'APPROVED') {
    return ProviderServiceStatus.approved;
  }
  if (completion != null &&
      (setupComplete ?? allServiceFlagsComplete(completion)) &&
      (completion.verificationStatus == 'PENDING' ||
          assignment?.verificationStatus == 'PENDING')) {
    return ProviderServiceStatus.pendingApproval;
  }
  return completion == null ? null : ProviderServiceStatus.setupRequired;
}

String humanizeOptionCode(String code) => code
    .replaceAll(RegExp(r'[_\-]+'), ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .map(
      (word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
    )
    .join(' ');

import '../domain/provider_completion.dart';

final class UnsupportedOnboardingStep implements Exception {
  const UnsupportedOnboardingStep();
}

ProviderCompletion parseProviderCompletion(Object? value) {
  final json = _object(value);
  final stepValue = _string(json, 'nextStep');
  final steps = ProviderOnboardingStep.values.where(
    (step) => step.wireValue == stepValue,
  );
  if (steps.isEmpty) throw const UnsupportedOnboardingStep();
  final percentage = json['completionPercentage'];
  if (percentage is! num ||
      !percentage.isFinite ||
      percentage < 0 ||
      percentage > 100) {
    throw const FormatException('Invalid completion percentage');
  }
  final services = json['services'];
  if (services is! List) throw const FormatException('Invalid services');
  return ProviderCompletion(
    profileCompleted: _bool(json, 'profileCompleted'),
    marketSelected: _bool(json, 'marketSelected'),
    serviceSelected: _bool(json, 'serviceSelected'),
    allActiveServicesApproved: _bool(json, 'allActiveServicesApproved'),
    completionPercentage: percentage,
    nextStep: steps.single,
    services: services.map((value) {
      final service = _object(value);
      return ProviderServiceCompletion(
        assignmentId: _id(service, 'assignmentId'),
        serviceTypeId: _id(service, 'serviceTypeId'),
        serviceName: _string(service, 'serviceName'),
        documentsCompleted: _bool(service, 'documentsCompleted'),
        skillsCompleted: _bool(service, 'skillsCompleted'),
        certificatesCompleted: _bool(service, 'certificatesCompleted'),
        educationCompleted: _bool(service, 'educationCompleted'),
        availabilityCompleted: _bool(service, 'availabilityCompleted'),
        serviceAreasCompleted: _bool(service, 'serviceAreasCompleted'),
        optionsCompleted: _bool(service, 'optionsCompleted'),
        customRequirementsCompleted: _bool(
          service,
          'customRequirementsCompleted',
        ),
        verificationStatus: _string(service, 'verificationStatus'),
        effectiveStatus: _string(service, 'effectiveStatus'),
      );
    }).toList(),
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid object');
  }
  return value;
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw const FormatException('Invalid flag');
  return value;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid text');
  }
  return value;
}

int _id(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw const FormatException('Invalid identifier');
  }
  return value;
}

import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';

String? validateSubServices(ProviderOnboardingSchema schema, Set<int> ids) {
  if (!schema.options.map((o) => o.optionId).toSet().containsAll(ids)) {
    return 'Some saved sub-services are no longer available. Retry to reload your service.';
  }
  final s = schema.serviceSetup;
  if (s.optionsRequired && s.minimumOptionSelections == null) {
    return 'Sub-service selection rules are unavailable. Please retry.';
  }
  final min = s.minimumOptionSelections, max = s.maximumOptionSelections;
  if (min != null && ids.length < min) {
    return 'Select at least $min sub-service${min == 1 ? '' : 's'}.';
  }
  if (max != null && ids.length > max) {
    return 'Select no more than $max sub-service${max == 1 ? '' : 's'}.';
  }
  return null;
}

String subServiceGuidance(ProviderOnboardingSchema schema) {
  final s = schema.serviceSetup,
      min = s.minimumOptionSelections,
      max = s.maximumOptionSelections;
  if (min != null && max != null) return 'Select $min–$max sub-services';
  if (min != null) {
    return 'Select at least $min sub-service${min == 1 ? '' : 's'}';
  }
  if (max != null) return 'Select up to $max sub-services';
  return s.optionsRequired
      ? 'Choose the services you provide'
      : 'Select applicable sub-services';
}

final class ProviderServiceInput {
  const ProviderServiceInput({
    required this.providerTypeId,
    required this.experienceYears,
  });
  final int providerTypeId;
  final double experienceYears;
  bool get isValid =>
      providerTypeId > 0 && experienceYears.isFinite && experienceYears >= 0;
  Map<String, dynamic> toJson() => {
    'providerTypeId': providerTypeId,
    'experienceYears': experienceYears,
  };
  static double? parseExperience(String? text) {
    final value = double.tryParse(text?.trim() ?? '');
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  static String? validateExperience(String? text) =>
      parseExperience(text) == null
      ? 'Enter a valid number of years, zero or greater.'
      : null;
}

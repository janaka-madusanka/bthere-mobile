enum ProviderGender {
  male('MALE', 'Male'),
  female('FEMALE', 'Female');

  const ProviderGender(this.wireValue, this.label);
  final String wireValue, label;

  /// Unknown/missing values remain unselected rather than defaulting to Male.
  static ProviderGender? tryParse(Object? value) => switch (value) {
    'MALE' => ProviderGender.male,
    'FEMALE' => ProviderGender.female,
    _ => null,
  };
}

enum ProviderAvailability {
  available('AVAILABLE', 'Available'),
  unavailable('UNAVAILABLE', 'Unavailable'),
  offline('OFFLINE', 'Offline');

  const ProviderAvailability(this.wireValue, this.label);
  final String wireValue, label;
}

final class ProviderProfileInput {
  const ProviderProfileInput({
    required this.marketId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.availabilityStatus,
    this.bio,
  });
  final int marketId;
  final String firstName, lastName;
  final String? bio;
  final DateTime dateOfBirth;
  final ProviderGender gender;
  final ProviderAvailability availabilityStatus;
  String? get profilePhoto => null;

  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? validationMessage(DateTime today) {
    if (marketId <= 0) return 'Select an available market.';
    if (requiredText(firstName) != null || requiredText(lastName) != null) {
      return 'First and last name are required.';
    }
    final date = DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);
    if (dateOfBirth.year < 1 || dateOfBirth.year > 9999) {
      return 'Select a valid date of birth.';
    }
    if (date.isAfter(DateTime(today.year, today.month, today.day))) {
      return 'Date of birth cannot be in the future.';
    }
    return null;
  }
}

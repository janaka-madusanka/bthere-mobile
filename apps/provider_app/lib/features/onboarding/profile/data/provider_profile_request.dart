import '../domain/provider_profile_input.dart';

Map<String, dynamic> serializeProviderProfile(ProviderProfileInput input) {
  String? optional(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  final date = input.dateOfBirth;
  return {
    'firstName': input.firstName.trim(),
    'lastName': input.lastName.trim(),
    'nicNumber': optional(input.nicNumber),
    'passportNumber': optional(input.passportNumber),
    'dateOfBirth':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'gender': input.gender.wireValue,
    'profilePhoto': input.profilePhoto,
    'bio': optional(input.bio),
    'availabilityStatus': input.availabilityStatus.wireValue,
    'marketId': input.marketId,
  };
}

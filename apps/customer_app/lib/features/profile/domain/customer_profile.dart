class CustomerProfileInput {
  const CustomerProfileInput({
    required this.firstName,
    required this.lastName,
    required this.addressLine1,
    required this.city,
    required this.country,
    this.addressLine2,
    this.district,
    this.province,
    this.postalCode,
    this.profilePhoto,
  });
  final String firstName, lastName, addressLine1, city, country;
  final String? addressLine2, district, province, postalCode, profilePhoto;
  Map<String, Object?> toJson() => {
    'firstName': firstName.trim(),
    'lastName': lastName.trim(),
    'addressLine1': addressLine1.trim(),
    'city': city.trim(),
    'country': country.trim(),
    'addressLine2': optional(addressLine2),
    'district': optional(district),
    'province': optional(province),
    'postalCode': optional(postalCode),
    'profilePhoto': optional(profilePhoto),
  };
  bool get valid => toJson().entries.every((entry) {
    final value = entry.value;
    if (value == null) {
      return ![
        'firstName',
        'lastName',
        'addressLine1',
        'city',
        'country',
      ].contains(entry.key);
    }
    final max = switch (entry.key) {
      'addressLine1' || 'addressLine2' => 255,
      'postalCode' => 20,
      'profilePhoto' => 2048,
      _ => 100,
    };
    return value is String && value.isNotEmpty && value.runes.length <= max;
  });
  static String? optional(String? text) =>
      text == null || text.trim().isEmpty ? null : text.trim();
}

class CustomerProfile {
  const CustomerProfile({
    required this.customerId,
    required this.userId,
    required this.details,
    required this.status,
    required this.profileCompleted,
  });
  final int customerId, userId;
  final CustomerProfileInput details;
  final String status;
  final bool profileCompleted;

  factory CustomerProfile.fromJson(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Invalid customer profile');
    }
    String text(String key) {
      final value = body[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid profile text');
      }
      return value;
    }

    String? nullable(String key) {
      final value = body[key];
      if (value != null && value is! String) {
        throw const FormatException('Invalid optional profile text');
      }
      return value as String?;
    }

    final customerId = body['customerId'],
        userId = body['userId'],
        completed = body['profileCompleted'];
    if (customerId is! int ||
        customerId <= 0 ||
        userId is! int ||
        userId <= 0 ||
        completed is! bool) {
      throw const FormatException('Invalid customer profile identity');
    }
    return CustomerProfile(
      customerId: customerId,
      userId: userId,
      status: text('status'),
      profileCompleted: completed,
      details: CustomerProfileInput(
        firstName: text('firstName'),
        lastName: text('lastName'),
        addressLine1: text('addressLine1'),
        city: text('city'),
        country: text('country'),
        addressLine2: nullable('addressLine2'),
        district: nullable('district'),
        province: nullable('province'),
        postalCode: nullable('postalCode'),
        profilePhoto: nullable('profilePhoto'),
      ),
    );
  }
}

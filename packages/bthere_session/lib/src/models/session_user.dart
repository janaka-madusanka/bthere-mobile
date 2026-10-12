/// Account metadata stored alongside credentials in the same secure record.
/// No Provider profile, password, or OTP is retained here.
final class SessionUser {
  SessionUser({
    required this.id,
    required this.username,
    required this.status,
    required List<String> roles,
    this.email,
    this.phoneNumber,
    this.emailVerified,
    this.phoneVerified,
  }) : roles = List.unmodifiable(roles) {
    if (id <= 0 ||
        username.trim().isEmpty ||
        status.trim().isEmpty ||
        roles.isEmpty ||
        roles.any((role) => role.trim().isEmpty)) {
      throw ArgumentError('Invalid session account metadata.');
    }
  }
  final int id;
  final String username, status;
  final List<String> roles;
  final String? email, phoneNumber;
  final bool? emailVerified, phoneVerified;

  factory SessionUser.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid session account.');
    }
    final id = value['id'],
        username = value['username'],
        status = value['status'],
        roles = value['roles'];
    if (id is! int ||
        username is! String ||
        status is! String ||
        roles is! List ||
        roles.any((role) => role is! String)) {
      throw const FormatException('Invalid session account.');
    }
    String? text(String key) {
      final item = value[key];
      if (item != null && item is! String) {
        throw const FormatException('Invalid account text.');
      }
      return item as String?;
    }

    bool? flag(String key) {
      final item = value[key];
      if (item != null && item is! bool) {
        throw const FormatException('Invalid account flag.');
      }
      return item as bool?;
    }

    return SessionUser(
      id: id,
      username: username,
      status: status,
      roles: roles.cast<String>(),
      email: text('email'),
      phoneNumber: text('phoneNumber'),
      emailVerified: flag('emailVerified'),
      phoneVerified: flag('phoneVerified'),
    );
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'status': status,
    'roles': roles,
    'email': email,
    'phoneNumber': phoneNumber,
    'emailVerified': emailVerified,
    'phoneVerified': phoneVerified,
  };
}

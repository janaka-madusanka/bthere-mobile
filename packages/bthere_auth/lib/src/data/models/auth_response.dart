import '../../domain/models/auth_user.dart';

const providerAccountType = 'SERVICE_PROVIDER';

Never invalidAuthResponse() =>
    throw const FormatException('Invalid authentication response.');

Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) invalidAuthResponse();
  return value;
}

String requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) invalidAuthResponse();
  return value;
}

String? optionalText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) invalidAuthResponse();
  return value;
}

bool? optionalBoolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! bool) invalidAuthResponse();
  return value;
}

int positiveSeconds(Map<String, dynamic> json) {
  final value = json['expiresIn'];
  if (value is! int || value <= 0) invalidAuthResponse();
  return value;
}

AuthUser parseUser(Object? value, {bool registration = false}) {
  final json = jsonObject(value);
  final id = json['id'];
  final roles = json['roles'];
  if (id is! int ||
      id <= 0 ||
      roles is! List ||
      roles.any((role) => role is! String || role.trim().isEmpty)) {
    invalidAuthResponse();
  }
  final email = optionalText(json, 'email');
  final emailVerified = optionalBoolean(json, 'emailVerified');
  final phoneVerified = optionalBoolean(json, 'phoneVerified');
  if (registration &&
      (email == null || emailVerified == null || phoneVerified == null)) {
    invalidAuthResponse();
  }
  return AuthUser(
    id: id,
    username: requiredText(json, 'username'),
    email: email,
    phoneNumber: optionalText(json, 'phoneNumber'),
    status: requiredText(json, 'status'),
    emailVerified: emailVerified,
    phoneVerified: phoneVerified,
    roles: roles.cast<String>(),
  );
}

/// Internal only. Credentials never cross the repository's domain return boundary.
final class AuthTokenResponse {
  const AuthTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthTokenResponse.parse(Object? value) {
    final json = jsonObject(value);
    final access = requiredText(json, 'accessToken');
    final refresh = requiredText(json, 'refreshToken');
    if (access.contains(RegExp(r'\s')) || refresh.contains(RegExp(r'\s'))) {
      invalidAuthResponse();
    }
    return AuthTokenResponse(
      accessToken: access,
      refreshToken: refresh,
      tokenType: requiredText(json, 'tokenType'),
      expiresIn: positiveSeconds(json),
      user: parseUser(json['user']),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final AuthUser user;
}

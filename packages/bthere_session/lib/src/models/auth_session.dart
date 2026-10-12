import 'session_user.dart';

/// Secure credentials, expiry and optional account metadata; never log values.
final class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required DateTime expiresAt,
    this.user,
  }) : expiresAt = expiresAt.toUtc() {
    if (accessToken.trim().isEmpty ||
        refreshToken.trim().isEmpty ||
        tokenType.trim().isEmpty) {
      throw ArgumentError('Session credential fields must be non-empty.');
    }
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;
  final SessionUser? user;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}

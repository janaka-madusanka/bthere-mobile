/// Authentication account metadata only. No credentials or Provider profile.
final class AuthUser {
  AuthUser({
    required this.id,
    required this.username,
    required this.status,
    required List<String> roles,
    this.email,
    this.phoneNumber,
    this.emailVerified,
    this.phoneVerified,
    this.marketId,
  }) : roles = List.unmodifiable(roles);

  final int id;
  final int? marketId;
  final String username;
  final String? email;
  final String? phoneNumber;
  final String status;
  final bool? emailVerified;
  final bool? phoneVerified;
  final List<String> roles;
}

/// Registration creates an account, not an authenticated session.
final class RegistrationAccount {
  const RegistrationAccount(this.account);
  final AuthUser account;

  int get id => account.id;
  int? get marketId => account.marketId;
  String get username => account.username;
  String? get email => account.email;
  String? get phoneNumber => account.phoneNumber;
  String get status => account.status;
  bool? get emailVerified => account.emailVerified;
  bool? get phoneVerified => account.phoneVerified;
  List<String> get roles => account.roles;
}

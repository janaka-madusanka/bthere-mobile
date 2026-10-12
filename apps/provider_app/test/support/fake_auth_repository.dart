import 'dart:async';

import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_common/bthere_common.dart';

final testAuthUser = AuthUser(
  id: 1,
  username: 'provider',
  email: 'provider@example.com',
  status: 'PENDING',
  roles: ['SERVICE_PROVIDER'],
);
final testRegistration = RegistrationAccount(testAuthUser);

class FakeAuthRepository implements ProviderAuthRepository {
  int logins = 0;
  String? loginIdentifier;
  String? loginPassword;
  Completer<Result<AuthUser>>? pendingLogin;
  Result<AuthUser>? loginResult;
  bool throwLogin = false;
  @override
  Future<Result<AuthUser>> loginProvider({
    required String identifier,
    required String password,
  }) async {
    logins++;
    loginIdentifier = identifier;
    loginPassword = password;
    if (throwLogin) throw StateError('synthetic private login exception');
    final result = pendingLogin == null
        ? loginResult ?? Success(testAuthUser)
        : await pendingLogin!.future;
    if (result.isSuccess) await persistVerifiedSession?.call();
    return result;
  }

  int googleAuthentications = 0;
  String? googleToken;
  Completer<Result<AuthUser>>? pendingGoogle;
  Result<AuthUser>? googleResult;
  @override
  Future<Result<AuthUser>> authenticateProviderWithGoogle(
    String idToken,
  ) async {
    googleAuthentications++;
    googleToken = idToken;
    final result = pendingGoogle == null
        ? googleResult ?? Success(testAuthUser)
        : await pendingGoogle!.future;
    if (result.isSuccess) await persistVerifiedSession?.call();
    return result;
  }

  int registrations = 0;
  int verifications = 0;
  ProviderEmailRegistrationRequest? registrationRequest;
  EmailOtpVerificationRequest? verificationRequest;
  Completer<Result<RegistrationAccount>>? pendingRegistration;
  Completer<Result<AuthUser>>? pendingVerification;
  Result<RegistrationAccount>? registrationResult;
  Result<AuthUser>? verificationResult;
  Future<void> Function()? persistVerifiedSession;
  bool throwRegistration = false;
  bool throwVerification = false;

  @override
  Future<Result<RegistrationAccount>> registerProviderWithEmail(
    ProviderEmailRegistrationRequest request,
  ) async {
    registrations++;
    registrationRequest = request;
    if (throwRegistration) throw StateError('synthetic private exception');
    return pendingRegistration == null
        ? registrationResult ?? Success(testRegistration)
        : await pendingRegistration!.future;
  }

  @override
  Future<Result<AuthUser>> verifyProviderEmail(
    EmailOtpVerificationRequest request,
  ) async {
    verifications++;
    verificationRequest = request;
    if (throwVerification) throw StateError('synthetic private exception');
    final result = pendingVerification == null
        ? verificationResult ?? Success(testAuthUser)
        : await pendingVerification!.future;
    if (result.isSuccess) await persistVerifiedSession?.call();
    return result;
  }

  @override
  Future<Result<OtpRequestInfo>> requestProviderPhoneOtp(
    ProviderPhoneOtpRequest request,
  ) => throw StateError('Phone UI must not be used');
  @override
  Future<Result<AuthUser>> verifyProviderPhoneOtp(
    ProviderPhoneOtpVerificationRequest request,
  ) => throw StateError('Phone UI must not be used');
}

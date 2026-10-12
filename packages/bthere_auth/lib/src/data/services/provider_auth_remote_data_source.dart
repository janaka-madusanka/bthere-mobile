import 'package:bthere_network/bthere_network.dart';

import '../../domain/models/auth_requests.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/models/otp_request_info.dart';
import '../models/auth_response.dart';

final class ProviderAuthRemoteDataSource {
  const ProviderAuthRemoteDataSource(this._client);
  final ApiClient _client;

  Future<AuthTokenResponse> login(String identifier, String password) async {
    final response = await _client.post<Object?>(
      '/auth/login',
      requiresAuth: false,
      data: {'identifier': identifier, 'password': password},
    );
    return AuthTokenResponse.parse(response.data);
  }

  Future<AuthTokenResponse> authenticateGoogle(String idToken) async {
    final response = await _client.post<Object?>(
      '/auth/google',
      requiresAuth: false,
      data: {'idToken': idToken, 'type': providerAccountType},
    );
    return AuthTokenResponse.parse(response.data);
  }

  Future<RegistrationAccount> register(
    ProviderEmailRegistrationRequest request,
  ) async {
    final response = await _client.post<Object?>(
      '/auth/register',
      requiresAuth: false,
      data: {
        'email': request.email,
        'password': request.password,
        'accountType': providerAccountType,
      },
    );
    if (response.statusCode != 201) invalidAuthResponse();
    return RegistrationAccount(parseUser(response.data, registration: true));
  }

  Future<AuthTokenResponse> verifyEmail(
    EmailOtpVerificationRequest request,
  ) async {
    final response = await _client.post<Object?>(
      '/auth/email/verify',
      requiresAuth: false,
      data: {'email': request.email, 'otp': request.otp},
    );
    return AuthTokenResponse.parse(response.data);
  }

  Future<OtpRequestInfo> requestPhone(ProviderPhoneOtpRequest request) async {
    final response = await _client.post<Object?>(
      '/auth/otp/request',
      requiresAuth: false,
      data: {
        'phoneNumber': request.phoneNumber,
        'accountType': providerAccountType,
      },
    );
    if (response.statusCode != 202) invalidAuthResponse();
    final json = jsonObject(response.data);
    return OtpRequestInfo(
      message: requiredText(json, 'message'),
      expiresIn: positiveSeconds(json),
    );
  }

  Future<AuthTokenResponse> verifyPhone(
    ProviderPhoneOtpVerificationRequest request,
  ) async {
    final response = await _client.post<Object?>(
      '/auth/otp/verify',
      requiresAuth: false,
      data: {
        'phoneNumber': request.phoneNumber,
        'otp': request.otp,
        'accountType': providerAccountType,
      },
    );
    return AuthTokenResponse.parse(response.data);
  }
}

import 'package:bthere_common/bthere_common.dart';

import '../models/auth_requests.dart';
import '../models/auth_user.dart';
import '../models/otp_request_info.dart';

/// Only the currently confirmed Provider contracts; no assumptions about Customer.
abstract interface class ProviderAuthRepository {
  Future<Result<AuthUser>> loginProvider({
    required String identifier,
    required String password,
  });
  Future<Result<AuthUser>> authenticateProviderWithGoogle(String idToken);
  Future<Result<RegistrationAccount>> registerProviderWithEmail(
    ProviderEmailRegistrationRequest request,
  );
  Future<Result<AuthUser>> verifyProviderEmail(
    EmailOtpVerificationRequest request,
  );
  Future<Result<OtpRequestInfo>> requestProviderPhoneOtp(
    ProviderPhoneOtpRequest request,
  );
  Future<Result<AuthUser>> verifyProviderPhoneOtp(
    ProviderPhoneOtpVerificationRequest request,
  );
}

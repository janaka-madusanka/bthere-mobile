/// Request values are transient; never log or persist passwords/OTPs.
final class ProviderEmailRegistrationRequest {
  const ProviderEmailRegistrationRequest({
    required this.email,
    required this.password,
  });
  final String email;
  final String password;
}

final class EmailOtpVerificationRequest {
  const EmailOtpVerificationRequest({required this.email, required this.otp});
  final String email;
  final String otp;
}

final class ProviderPhoneOtpRequest {
  const ProviderPhoneOtpRequest({required this.phoneNumber});
  final String phoneNumber;
}

final class ProviderPhoneOtpVerificationRequest {
  const ProviderPhoneOtpVerificationRequest({
    required this.phoneNumber,
    required this.otp,
  });
  final String phoneNumber;
  final String otp;
}

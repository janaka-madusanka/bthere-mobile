final class OtpRequestInfo {
  const OtpRequestInfo({required this.message, required this.expiresIn});

  final String message;
  final int expiresIn;
  Duration get validity => Duration(seconds: expiresIn);
}

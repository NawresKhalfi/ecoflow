/// Session de vérification SMS en cours.
class OtpSession {
  const OtpSession({
    required this.verificationId,
    required this.phoneNumber,
    required this.sentAt,
  });

  final String verificationId;
  final String phoneNumber;
  final DateTime sentAt;
}

/// Règles OTP (US-001) : code valable 5 minutes, renvoi après 30 s.
class OtpPolicy {
  const OtpPolicy({
    this.validity = const Duration(minutes: 5),
    this.resendCooldown = const Duration(seconds: 30),
  });

  final Duration validity;
  final Duration resendCooldown;

  bool isExpired(OtpSession s, DateTime now) =>
      !now.isBefore(s.sentAt.add(validity));

  Duration remaining(OtpSession s, DateTime now) {
    final left = s.sentAt.add(validity).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool canResend(OtpSession s, DateTime now) =>
      !now.isBefore(s.sentAt.add(resendCooldown));
}

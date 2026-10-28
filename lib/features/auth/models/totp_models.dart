class TotpStatus {
  const TotpStatus({
    required this.enabled,
    this.confirmedAt,
    this.recoveryCodesRemaining = 0,
  });

  final bool enabled;
  final DateTime? confirmedAt;
  final int recoveryCodesRemaining;

  factory TotpStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['confirmed_at'];
    return TotpStatus(
      enabled: json['enabled'] as bool? ?? false,
      confirmedAt: raw != null ? DateTime.tryParse(raw.toString()) : null,
      recoveryCodesRemaining:
          (json['recovery_codes_remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class TotpEnrollment {
  const TotpEnrollment({required this.secret, required this.otpauthUri});

  final String secret;
  final String otpauthUri;

  factory TotpEnrollment.fromJson(Map<String, dynamic> json) {
    return TotpEnrollment(
      secret: json['secret'] as String? ?? '',
      otpauthUri: json['otpauth_uri'] as String? ?? '',
    );
  }
}

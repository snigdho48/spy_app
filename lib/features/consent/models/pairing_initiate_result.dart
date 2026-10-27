class PairingInitiateResult {
  const PairingInitiateResult({
    required this.pairingId,
    required this.deviceId,
    required this.pairingCode,
    required this.qrPayload,
    required this.expiresAt,
  });

  final String pairingId;
  final String deviceId;
  final String pairingCode;
  final String qrPayload;
  final DateTime expiresAt;

  factory PairingInitiateResult.fromJson(Map<String, dynamic> json) {
    return PairingInitiateResult(
      pairingId: json['pairing_id'].toString(),
      deviceId: json['device_id'].toString(),
      pairingCode: json['pairing_code'] as String,
      qrPayload: json['qr_payload'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

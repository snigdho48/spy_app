class AuthSession {
  const AuthSession({
    required this.id,
    required this.deviceLabel,
    this.userAgent = '',
    this.ipAddress,
    this.createdAt,
    this.lastUsedAt,
    this.isCurrent = false,
  });

  final String id;
  final String deviceLabel;
  final String userAgent;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final bool isCurrent;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return AuthSession(
      id: json['id'].toString(),
      deviceLabel: json['device_label'] as String? ?? 'Unknown device',
      userAgent: json['user_agent'] as String? ?? '',
      ipAddress: json['ip_address'] as String?,
      createdAt: parse(json['created_at']),
      lastUsedAt: parse(json['last_used_at']),
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }
}

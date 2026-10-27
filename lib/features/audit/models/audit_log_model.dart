class AuditLogModel {
  const AuditLogModel({
    required this.id,
    required this.action,
    required this.resourceType,
    required this.createdAt,
    this.actorId,
    this.resourceId,
    this.metadata = const {},
    this.ipAddress,
  });

  final String id;
  final String? actorId;
  final String action;
  final String resourceType;
  final String? resourceId;
  final Map<String, dynamic> metadata;
  final String? ipAddress;
  final DateTime createdAt;

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'].toString(),
      actorId: json['actor_id']?.toString(),
      action: json['action'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      resourceId: json['resource_id']?.toString(),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ipAddress: json['ip_address']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get title {
    return switch (action) {
      'device.disconnected' => 'Device disconnected',
      'device.deleted' => 'Device deleted',
      'device.paired' => 'Device paired',
      'device.pairing.initiated' => 'Pairing started',
      'device.pairing.completed' => 'Device paired',
      'consent.granted' => 'Consent granted',
      'consent.revoked' => 'Consent revoked',
      _ => action.replaceAll('.', ' '),
    };
  }
}

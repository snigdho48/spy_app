/// A live screen-share session as returned by the backend.
///
/// Frames themselves never flow through this model — only the session
/// lifecycle. Live frames travel over the dedicated screen WebSocket
/// ([ScreenStreamClient]).
class ScreenShareSession {
  const ScreenShareSession({
    required this.id,
    required this.deviceId,
    required this.status,
    required this.wsPath,
    this.deviceName,
    this.requestedByEmail,
    this.startedAt,
    this.endedAt,
    this.consentScopes = const [],
  });

  final String id;
  final String deviceId;
  final String status; // requested | active | ended | denied | expired
  final String wsPath; // e.g. ws/v1/screen/<id>/
  final String? deviceName;
  final String? requestedByEmail;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Active consent scopes for the device, when the backend includes them in
  /// the session payload. Used for a local, defence-in-depth `screen` check
  /// before capture (the server also enforces this on request/start/WS).
  final List<String> consentScopes;

  bool get isActive => status == 'active';
  bool get isOpen => status == 'requested' || status == 'active';

  /// Whether the payload carried the device's active consent scopes at all.
  bool get hasConsentInfo => consentScopes.isNotEmpty;

  /// Whether `screen` is among the reported active consent scopes.
  bool get localScreenConsentActive => consentScopes.contains('screen');

  factory ScreenShareSession.fromJson(Map<String, dynamic> json) {
    final rawScopes = json['consent_scopes'] ?? json['scopes'];
    final scopes = rawScopes is List
        ? rawScopes.map((e) => e.toString()).toList()
        : const <String>[];
    return ScreenShareSession(
      id: json['id'].toString(),
      deviceId: json['device_id'].toString(),
      status: json['status'] as String? ?? 'requested',
      wsPath: json['ws_url'] as String? ?? '',
      deviceName: json['device_name'] as String?,
      requestedByEmail: json['requested_by_email'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      consentScopes: scopes,
    );
  }
}

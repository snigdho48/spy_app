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
    this.controlStatus = 'none',
    this.controlRequestedAt,
    this.controlStartedAt,
    this.controlEndedAt,
    this.controlEndedReason,
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

  /// Per-session remote-control grant: none | requested | approved | denied.
  /// View stays scope-based; injecting input requires an explicit approve.
  final String controlStatus;
  final DateTime? controlRequestedAt;
  final DateTime? controlStartedAt;
  final DateTime? controlEndedAt;
  final String? controlEndedReason;

  bool get isActive => status == 'active';
  bool get isOpen => status == 'requested' || status == 'active';

  bool get controlApproved => controlStatus == 'approved';
  bool get controlRequested => controlStatus == 'requested';
  bool get controlDenied => controlStatus == 'denied';

  /// Whether the payload carried the device's active consent scopes at all.
  bool get hasConsentInfo => consentScopes.isNotEmpty;

  /// Whether `screen` is among the reported active consent scopes.
  bool get localScreenConsentActive => consentScopes.contains('screen');

  ScreenShareSession copyWith({
    String? status,
    String? controlStatus,
    DateTime? controlRequestedAt,
    DateTime? controlStartedAt,
    DateTime? controlEndedAt,
    String? controlEndedReason,
  }) {
    return ScreenShareSession(
      id: id,
      deviceId: deviceId,
      status: status ?? this.status,
      wsPath: wsPath,
      deviceName: deviceName,
      requestedByEmail: requestedByEmail,
      startedAt: startedAt,
      endedAt: endedAt,
      consentScopes: consentScopes,
      controlStatus: controlStatus ?? this.controlStatus,
      controlRequestedAt: controlRequestedAt ?? this.controlRequestedAt,
      controlStartedAt: controlStartedAt ?? this.controlStartedAt,
      controlEndedAt: controlEndedAt ?? this.controlEndedAt,
      controlEndedReason: controlEndedReason ?? this.controlEndedReason,
    );
  }

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
      controlStatus: json['control_status'] as String? ?? 'none',
      controlRequestedAt: json['control_requested_at'] != null
          ? DateTime.tryParse(json['control_requested_at'].toString())
          : null,
      controlStartedAt: json['control_started_at'] != null
          ? DateTime.tryParse(json['control_started_at'].toString())
          : null,
      controlEndedAt: json['control_ended_at'] != null
          ? DateTime.tryParse(json['control_ended_at'].toString())
          : null,
      controlEndedReason: json['control_ended_reason'] as String?,
    );
  }

  /// Pending poll may be a single session object or `{results: [...]}`.
  static ScreenShareSession? fromPendingResponse(Map<String, dynamic> json) {
    if (json['id'] != null) {
      return ScreenShareSession.fromJson(json);
    }
    final raw = json['results'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          return ScreenShareSession.fromJson(Map<String, dynamic>.from(item));
        }
      }
    }
    return null;
  }
}

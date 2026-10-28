class LiveMediaSession {
  const LiveMediaSession({
    required this.id,
    required this.deviceId,
    required this.mediaKind,
    required this.cameraFacing,
    required this.status,
    required this.wsPath,
    this.deviceName,
    this.requestedByEmail,
  });

  final String id;
  final String deviceId;
  final String mediaKind; // camera | microphone | both
  final String cameraFacing; // front | back
  final String status;
  final String wsPath;
  final String? deviceName;
  final String? requestedByEmail;

  factory LiveMediaSession.fromJson(Map<String, dynamic> json) {
    return LiveMediaSession(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      mediaKind: json['media_kind']?.toString() ?? 'camera',
      cameraFacing: json['camera_facing']?.toString() ?? 'back',
      status: json['status']?.toString() ?? '',
      wsPath: json['ws_url']?.toString() ?? '',
      deviceName: json['device_name']?.toString(),
      requestedByEmail: json['requested_by_email']?.toString(),
    );
  }
}

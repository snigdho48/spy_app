class SharingState {
  const SharingState({
    required this.paused,
    this.pausedUntil,
    this.resumesInSeconds,
  });

  final bool paused;
  final DateTime? pausedUntil;
  final int? resumesInSeconds;

  factory SharingState.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SharingState(paused: false);
    }
    final untilRaw = json['paused_until'];
    return SharingState(
      paused: json['paused'] as bool? ?? false,
      pausedUntil: untilRaw != null
          ? DateTime.tryParse(untilRaw.toString())
          : null,
      resumesInSeconds: (json['resumes_in_s'] as num?)?.toInt(),
    );
  }

  static const inactive = SharingState(paused: false);

  Map<String, dynamic> toJson() => {
        'paused': paused,
        if (pausedUntil != null) 'paused_until': pausedUntil!.toIso8601String(),
        if (resumesInSeconds != null) 'resumes_in_s': resumesInSeconds,
      };
}

class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.name,
    required this.platform,
    required this.status,
    this.lastSeenAt,
    this.tenantName,
    this.photoUrl,
    this.sharing = SharingState.inactive,
  });

  final String id;
  final String name;
  final String platform;
  final String status;
  final DateTime? lastSeenAt;
  final String? tenantName;
  final String? photoUrl;
  final SharingState sharing;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    if (list.length == 1) {
      final p = list.first;
      return p.length >= 2 ? p.substring(0, 2).toUpperCase() : p.toUpperCase();
    }
    return ('${list.first[0]}${list.last[0]}').toUpperCase();
  }

  String? get httpsPhotoUrl {
    final url = photoUrl?.trim();
    if (url == null || url.isEmpty) return null;
    return url.toLowerCase().startsWith('https://') ? url : null;
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      platform: json['platform'] as String,
      status: json['status'] as String,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
      tenantName: json['tenant_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      sharing: SharingState.fromJson(json['sharing'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'platform': platform,
        'status': status,
        if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
        if (tenantName != null) 'tenant_name': tenantName,
        if (photoUrl != null) 'photo_url': photoUrl,
        'sharing': sharing.toJson(),
      };

  DeviceModel copyWith({SharingState? sharing, String? photoUrl}) {
    return DeviceModel(
      id: id,
      name: name,
      platform: platform,
      status: status,
      lastSeenAt: lastSeenAt,
      tenantName: tenantName,
      photoUrl: photoUrl ?? this.photoUrl,
      sharing: sharing ?? this.sharing,
    );
  }
}

class OwnedDeviceStatus {
  const OwnedDeviceStatus({
    required this.deviceId,
    required this.deviceName,
    required this.status,
    required this.tenantName,
    required this.isLinked,
    this.sharing = SharingState.inactive,
  });

  final String deviceId;
  final String deviceName;
  final String status;
  final String tenantName;
  final bool isLinked;
  final SharingState sharing;

  factory OwnedDeviceStatus.fromJson(Map<String, dynamic> json) {
    return OwnedDeviceStatus(
      deviceId: json['device_id'].toString(),
      deviceName: json['device_name'] as String,
      status: json['status'] as String,
      tenantName: json['tenant_name'] as String? ?? '',
      isLinked: json['is_linked'] as bool? ?? false,
      sharing: SharingState.fromJson(json['sharing'] as Map<String, dynamic>?),
    );
  }
}

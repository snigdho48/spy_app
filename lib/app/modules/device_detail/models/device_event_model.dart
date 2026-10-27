class ContactPayload {
  const ContactPayload({
    this.contactName,
    this.contactPhotoUrl,
    this.isKnown = false,
    this.isFlagged = false,
    this.isRedacted = false,
  });

  final String? contactName;
  final String? contactPhotoUrl;
  final bool isKnown;
  final bool isFlagged;
  final bool isRedacted;

  String get initials {
    final name = (contactName ?? '').trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      final p = parts.first;
      return p.length >= 2 ? p.substring(0, 2).toUpperCase() : p.toUpperCase();
    }
    return ('${parts.first[0]}${parts.last[0]}').toUpperCase();
  }
}

class DeviceEventModel {
  const DeviceEventModel({
    required this.id,
    required this.deviceId,
    required this.eventType,
    required this.payload,
    required this.eventTimestamp,
  });

  final String id;
  final String deviceId;
  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime eventTimestamp;

  factory DeviceEventModel.fromJson(Map<String, dynamic> json) {
    return DeviceEventModel(
      id: json['id'].toString(),
      deviceId: json['device_id'].toString(),
      eventType: json['event_type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      eventTimestamp: DateTime.parse(json['event_timestamp'] as String),
    );
  }

  ContactPayload get contact {
    String? str(String key) {
      final v = payload[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    bool flag(String key) {
      final v = payload[key];
      if (v is bool) return v;
      if (v == null) return false;
      return v.toString().toLowerCase() == 'true';
    }

    final photo = str('contact_photo_url');
    final httpsPhoto =
        photo != null && photo.toLowerCase().startsWith('https://') ? photo : null;

    return ContactPayload(
      contactName: str('contact_name') ?? str('name') ?? str('sender_name'),
      contactPhotoUrl: httpsPhoto,
      isKnown: flag('is_known'),
      isFlagged: flag('is_flagged'),
      isRedacted: flag('is_redacted'),
    );
  }
}

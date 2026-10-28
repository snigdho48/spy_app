class SafeZoneModel {
  const SafeZoneModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    this.address = '',
    this.deviceId,
    this.displayLabel,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final int radiusM;
  final String? deviceId;
  final String? displayLabel;
  final bool enabled;

  String get label => (displayLabel != null && displayLabel!.isNotEmpty)
      ? displayLabel!
      : 'Safe Zone: $name';

  SafeZoneModel copyWith({
    String? name,
    double? lat,
    double? lng,
    int? radiusM,
    String? address,
    bool? enabled,
  }) {
    return SafeZoneModel(
      id: id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusM: radiusM ?? this.radiusM,
      address: address ?? this.address,
      deviceId: deviceId,
      displayLabel: displayLabel,
      enabled: enabled ?? this.enabled,
    );
  }

  factory SafeZoneModel.fromJson(Map<String, dynamic> json) {
    return SafeZoneModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusM: (json['radius_m'] as num?)?.toInt() ?? 100,
      deviceId: json['device_id']?.toString(),
      displayLabel: json['display_label'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

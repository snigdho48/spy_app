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
  });

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final int radiusM;
  final String? deviceId;
  final String? displayLabel;

  String get label => (displayLabel != null && displayLabel!.isNotEmpty)
      ? displayLabel!
      : 'Safe Zone: $name';

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
    );
  }
}

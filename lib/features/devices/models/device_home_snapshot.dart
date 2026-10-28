/// Lightweight care/location summary for home device rows (from existing events API).
class DeviceHomeSnapshot {
  const DeviceHomeSnapshot({
    this.batteryPercent,
    this.batteryCharging,
    this.placeLabel,
    this.locationAt,
  });

  final int? batteryPercent;
  final bool? batteryCharging;
  final String? placeLabel;
  final DateTime? locationAt;

  String get batteryCaption {
    if (batteryPercent == null) return 'Battery unknown';
    final charge = batteryCharging == true ? ' · Charging' : '';
    return '$batteryPercent%$charge';
  }

  String get geofenceCaption {
    if (placeLabel == null || placeLabel!.isEmpty) return 'No recent location';
    return placeLabel!;
  }

  Map<String, dynamic> toJson() => {
        if (batteryPercent != null) 'battery_percent': batteryPercent,
        if (batteryCharging != null) 'battery_charging': batteryCharging,
        if (placeLabel != null) 'place_label': placeLabel,
        if (locationAt != null) 'location_at': locationAt!.toIso8601String(),
      };

  factory DeviceHomeSnapshot.fromJson(Map<String, dynamic> json) {
    final loc = json['location_at'];
    return DeviceHomeSnapshot(
      batteryPercent: (json['battery_percent'] as num?)?.toInt(),
      batteryCharging: json['battery_charging'] as bool?,
      placeLabel: json['place_label'] as String?,
      locationAt: loc != null ? DateTime.tryParse(loc.toString()) : null,
    );
  }
}

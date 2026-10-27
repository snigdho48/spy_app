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
}

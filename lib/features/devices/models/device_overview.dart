import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/models/location_point.dart';

/// At-a-glance summary for a single accessible device, assembled from the
/// existing device list, telemetry, location and alerts feeds. Consumed by the
/// multi-device Fleet overview. All feed fields are optional so a VIEWER /
/// consent-off device still renders a card with whatever is available.
class DeviceOverview {
  const DeviceOverview({
    required this.device,
    this.batteryPercent,
    this.batteryCharging,
    this.lastLocation,
    this.unreadAlerts = 0,
    this.criticalAlerts = 0,
    this.accessDenied = false,
  });

  final DeviceModel device;
  final int? batteryPercent;
  final bool? batteryCharging;
  final LocationPoint? lastLocation;
  final int unreadAlerts;
  final int criticalAlerts;

  /// True when the device feeds returned 403 (VIEWER) or consent is off, so the
  /// card can explain the limited view instead of looking broken.
  final bool accessDenied;

  bool get isOnline => device.status.toLowerCase() == 'active';

  bool get isPaused => device.sharing.paused;

  DeviceOverview copyWith({
    int? batteryPercent,
    bool? batteryCharging,
    LocationPoint? lastLocation,
    int? unreadAlerts,
    int? criticalAlerts,
    bool? accessDenied,
  }) {
    return DeviceOverview(
      device: device,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryCharging: batteryCharging ?? this.batteryCharging,
      lastLocation: lastLocation ?? this.lastLocation,
      unreadAlerts: unreadAlerts ?? this.unreadAlerts,
      criticalAlerts: criticalAlerts ?? this.criticalAlerts,
      accessDenied: accessDenied ?? this.accessDenied,
    );
  }
}

/// Totals shown in the overview summary strip.
class FleetSummary {
  const FleetSummary({
    required this.totalDevices,
    required this.onlineDevices,
    required this.totalUnreadAlerts,
    required this.criticalAlerts,
  });

  final int totalDevices;
  final int onlineDevices;
  final int totalUnreadAlerts;
  final int criticalAlerts;

  bool get hasCritical => criticalAlerts > 0;
}

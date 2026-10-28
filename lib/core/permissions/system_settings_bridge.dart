import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Target system settings pages for permissions that Android does not expose as
/// a runtime request (they can only be toggled in Settings).
enum SystemSettingsPage {
  appDetails,
  accessibility,
  usageAccess,
  notificationListener,
  overlay,
  batteryOptimization,
  deviceAdmin,
}

/// Deep-links to the exact Android system settings page for a permission.
///
/// Uses the shared monitoring MethodChannel (`org.hmg.spy_love/monitoring`) to
/// fire the correct `Settings.ACTION_*` intent natively. If the native handler
/// is unavailable (older build / iOS), it falls back to the app's own settings
/// page via `permission_handler`, so the button is never a dead end.
class SystemSettingsBridge {
  SystemSettingsBridge._();

  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');

  static Future<void> open(SystemSettingsPage page) async {
    try {
      final handled = await _channel.invokeMethod<bool>('openSettingsPage', {
        'page': page.name,
      });
      if (handled == true) return;
    } on PlatformException {
      // fall through to app settings
    } on MissingPluginException {
      // fall through to app settings
    }
    await openAppSettings();
  }
}

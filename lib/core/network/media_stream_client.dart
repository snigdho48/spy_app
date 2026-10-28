import 'dart:async';
import 'dart:convert';

import 'package:one_request/one_request.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/storage/token_storage.dart';

/// WebSocket transport for live camera frames + mic PCM via LiveMediaConsumer.
class MediaStreamClient {
  MediaStreamClient(this._tokens);

  final TokenStorage _tokens;
  OneSocket? _socket;

  bool get isConnected => _socket?.state == SocketState.connected;

  Future<bool> connect(
    String sessionWsPath, {
    void Function(Map<String, dynamic> message)? onFrame,
    void Function(Map<String, dynamic> message)? onAudio,
    void Function(Map<String, dynamic> signal)? onSignal,
    void Function()? onClosed,
  }) async {
    await close();
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse(
      AppConfig.mediaWsUrl(sessionWsPath),
    ).replace(queryParameters: {'token': token});

    final socket = OneRequest.socket(
      url: uri.toString(),
      autoReconnect: false,
      headers: {'Authorization': 'Bearer $token'},
      onMessage: (message) {
        if (message is! Map) return;
        final map = Map<String, dynamic>.from(message);
        switch (map['type']) {
          case 'media.frame':
            onFrame?.call(map);
          case 'media.audio':
            onAudio?.call(map);
          case 'media.signal':
            onSignal?.call(map);
          case 'media.closed':
            onSignal?.call({
              'type': 'media.signal',
              'data': {'signal': 'ended', 'reason': map['reason'] ?? 'closed'},
            });
        }
      },
      onState: (state) {
        if (state == SocketState.disconnected) onClosed?.call();
      },
    );
    _socket = socket;
    try {
      await socket.ready;
    } catch (_) {
      await close();
      return false;
    }
    if (socket.state == SocketState.disconnected) {
      await close();
      return false;
    }
    return true;
  }

  void sendFrame({
    required String jpegBase64,
    required int width,
    required int height,
    required String facing,
  }) {
    _socket?.send({
      'type': 'media.frame',
      'data': {
        'image': jpegBase64,
        'w': width,
        'h': height,
        'facing': facing,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    });
  }

  void sendAudio({
    required String pcmBase64,
    required int sampleRate,
    required int channels,
  }) {
    _socket?.send({
      'type': 'media.audio',
      'data': {
        'pcm': pcmBase64,
        'sampleRate': sampleRate,
        'channels': channels,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    });
  }

  void sendSignal(String signal, {Map<String, dynamic>? extra}) {
    _socket?.send({
      'type': 'media.signal',
      'data': {'signal': signal, ...?extra},
    });
  }

  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) await socket.close();
  }

  static List<int>? decodeJpeg(Map<String, dynamic> frame) {
    final data = frame['data'];
    if (data is! Map) return null;
    final image = data['image'];
    if (image is! String || image.isEmpty) return null;
    try {
      return base64Decode(image);
    } catch (_) {
      return null;
    }
  }

  static List<int>? decodePcm(Map<String, dynamic> audio) {
    final data = audio['data'];
    if (data is! Map) return null;
    final pcm = data['pcm'];
    if (pcm is! String || pcm.isEmpty) return null;
    try {
      return base64Decode(pcm);
    } catch (_) {
      return null;
    }
  }
}

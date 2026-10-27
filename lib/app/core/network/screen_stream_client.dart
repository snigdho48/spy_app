import 'dart:convert';

import 'package:one_request/one_request.dart';
import 'package:spy_love/app/core/config/app_config.dart';
import 'package:spy_love/app/core/storage/token_storage.dart';

/// Per-session WebSocket transport for live screen frames via
/// [OneRequest.socket], talking to the Django Channels `ScreenShareConsumer`.
///
/// Frames are relayed only — nothing is persisted. The monitored device is the
/// publisher ([sendFrame]); the monitor is a read-only viewer ([onFrame]).
/// Connection is still gated server-side on an active `screen` consent scope
/// and sharing-pause state; the consumer closes the socket if either changes.
class ScreenStreamClient {
  ScreenStreamClient(this._tokens);

  final TokenStorage _tokens;
  OneSocket? _socket;

  bool get isConnected => _socket?.state == SocketState.connected;

  /// Connects to the session socket.
  ///
  /// [onFrame] receives decoded `screen.frame` payloads (base64 JPEG + size).
  /// [onSignal] receives the full `screen.signal` control message. The control
  /// payload is nested under `data` (e.g. `data.signal == 'ended' | 'paused'`)
  /// because the backend consumer relays only `{type, session_id, data}` and
  /// drops any top-level fields.
  Future<bool> connect(
    String sessionWsPath, {
    void Function(Map<String, dynamic> frame)? onFrame,
    void Function(Map<String, dynamic> signal)? onSignal,
    void Function()? onClosed,
  }) async {
    await close();
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) return false;

    final uri = Uri.parse(AppConfig.screenWsUrl(sessionWsPath)).replace(
      queryParameters: {'token': token},
    );

    _socket = OneRequest.socket(
      url: uri.toString(),
      autoReconnect: false,
      headers: {'Authorization': 'Bearer $token'},
      onMessage: (message) {
        if (message is! Map) return;
        final map = Map<String, dynamic>.from(message);
        switch (map['type']) {
          case 'screen.frame':
            onFrame?.call(map);
            break;
          case 'screen.signal':
            onSignal?.call(map);
            break;
        }
      },
      onState: (state) {
        if (state == SocketState.disconnected) onClosed?.call();
      },
    );
    return true;
  }

  /// Publisher-only: push one JPEG frame (base64) with its dimensions.
  void sendFrame({required String jpegBase64, required int width, required int height}) {
    _socket?.send({
      'type': 'screen.frame',
      'data': {
        'image': jpegBase64,
        'w': width,
        'h': height,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    });
  }

  /// Sends a `screen.signal` control message (e.g. ended/paused).
  ///
  /// The signal and any extras are nested under `data` so they survive the
  /// backend consumer relay, which preserves only `{type, session_id, data}`.
  void sendSignal(String signal, [Map<String, dynamic>? extra]) {
    final data = <String, dynamic>{'signal': signal};
    if (extra != null) data.addAll(extra);
    _socket?.send({
      'type': 'screen.signal',
      'data': data,
    });
  }

  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close();
    }
  }

  /// Decodes the base64 JPEG payload from an [onFrame] message, or null.
  static List<int>? decodeFrameBytes(Map<String, dynamic> frame) {
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
}

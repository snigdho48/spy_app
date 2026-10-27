import 'dart:async';
import 'dart:convert';

import 'package:one_request/one_request.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/storage/token_storage.dart';

/// Per-session WebSocket transport for live screen frames via
/// [OneRequest.socket], talking to the Django Channels `ScreenShareConsumer`.
///
/// Frames are relayed only — nothing is persisted. The monitored device is the
/// publisher ([sendFrame]); the monitor is a read-only viewer ([onFrame]).
/// Connection is still gated server-side on an active `screen` consent scope
/// and sharing-pause state; the consumer closes the socket (and sends a
/// `screen.closed` control frame) if either changes.
class ScreenStreamClient {
  ScreenStreamClient(this._tokens);

  final TokenStorage _tokens;
  OneSocket? _socket;

  bool get isConnected => _socket?.state == SocketState.connected;

  /// Connects to the session socket and waits until the socket is actually
  /// open before returning. Returns `false` when there is no auth token or the
  /// handshake fails / is rejected (e.g. the consumer closes with 4001/4003
  /// for a missing token, revoked consent, or a paused share) — callers should
  /// surface that as an error instead of sitting on "waiting" forever.
  ///
  /// [onFrame] receives decoded `screen.frame` payloads (base64 JPEG + size).
  /// [onSignal] receives `screen.signal` and `screen.closed` control messages.
  /// The control payload is nested under `data` (e.g. `data.signal == 'ended' |
  /// 'paused'`) for `screen.signal`; a server-side `screen.closed` kick is
  /// normalised into the same `{data: {signal: 'ended', reason: ...}}` shape so
  /// viewers have a single code path for "the stream stopped".
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

    final socket = OneRequest.socket(
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
          case 'screen.closed':
            // Server-side kick (REST end / consent revoke / pause / expire).
            // Normalise to the signal shape so the viewer/publisher end cleanly
            // with a reason instead of only noticing the raw socket close.
            onSignal?.call({
              'type': 'screen.signal',
              'data': {
                'signal': 'ended',
                'reason': map['reason'] ?? 'closed',
              },
            });
            break;
          // 'screen.ready' is an informational handshake ack — no action.
        }
      },
      onState: (state) {
        if (state == SocketState.disconnected) onClosed?.call();
      },
    );
    _socket = socket;

    // Wait for the handshake. A rejected connection (closed by the consumer
    // before/ right after accept) must be reported as a failure, not a silent
    // success that leaves the UI stuck waiting for frames that never come.
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

  /// Sends a `screen.signal` control message (e.g. ended/paused). The signal
  /// and any extras are nested under `data` so they survive the backend relay,
  /// which keeps only `{type, session_id, data}`.
  void sendSignal(String signal, {Map<String, dynamic>? extra}) {
    _socket?.send({
      'type': 'screen.signal',
      'data': {'signal': signal, ...?extra},
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

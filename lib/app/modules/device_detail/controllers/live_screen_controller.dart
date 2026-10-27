import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:spy_love/app/core/network/screen_stream_client.dart';
import 'package:spy_love/app/modules/device_detail/models/screen_share_session.dart';
import 'package:spy_love/app/modules/device_detail/repositories/screen_share_repository.dart';

enum LiveScreenStatus { idle, requesting, waiting, live, ended, error }

/// Monitor-side controller for viewing a monitored device's live screen.
///
/// Read-only: it requests a session, opens the viewer WebSocket, and renders
/// relayed JPEG frames. All access is gated server-side by the `screen` consent
/// scope and sharing-pause; if consent is revoked or sharing is paused the
/// consumer closes the socket and we drop back to [LiveScreenStatus.ended].
class LiveScreenController extends ChangeNotifier {
  LiveScreenController(this._repo, this._stream);

  final ScreenShareRepository _repo;
  final ScreenStreamClient _stream;

  LiveScreenStatus _status = LiveScreenStatus.idle;
  Uint8List? _frame;
  String? _error;
  ScreenShareSession? _session;
  int _frameCount = 0;

  LiveScreenStatus get status => _status;
  Uint8List? get frame => _frame;
  String? get error => _error;
  int get frameCount => _frameCount;
  bool get isStreaming =>
      _status == LiveScreenStatus.live || _status == LiveScreenStatus.waiting;

  Future<void> start(String deviceId) async {
    if (isStreaming) return;
    _setStatus(LiveScreenStatus.requesting);
    _error = null;

    final requested = await _repo.requestSession(deviceId);
    if (requested.isRight) {
      _error = requested.right;
      _setStatus(LiveScreenStatus.error);
      return;
    }
    _session = requested.left;
    _setStatus(LiveScreenStatus.waiting);

    final connected = await _stream.connect(
      _session!.wsPath,
      onFrame: (frame) {
        final bytes = ScreenStreamClient.decodeFrameBytes(frame);
        if (bytes == null) return;
        _frame = Uint8List.fromList(bytes);
        _frameCount++;
        if (_status != LiveScreenStatus.live) {
          _status = LiveScreenStatus.live;
        }
        notifyListeners();
      },
      onSignal: (signal) {
        if (signal['signal'] == 'ended' || signal['signal'] == 'paused') {
          _setStatus(LiveScreenStatus.ended);
        }
      },
      onClosed: () {
        if (_status != LiveScreenStatus.ended &&
            _status != LiveScreenStatus.error) {
          _setStatus(LiveScreenStatus.ended);
        }
      },
    );

    if (!connected) {
      _error = 'Could not open the live screen stream.';
      _setStatus(LiveScreenStatus.error);
    }
  }

  Future<void> stop() async {
    final session = _session;
    await _stream.close();
    if (session != null) {
      await _repo.endSession(session.id, reason: 'monitor_stopped');
    }
    _session = null;
    _frame = null;
    _setStatus(LiveScreenStatus.ended);
  }

  void _setStatus(LiveScreenStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_stream.close());
    super.dispose();
  }
}

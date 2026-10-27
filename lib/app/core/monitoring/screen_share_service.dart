import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:spy_love/app/core/monitoring/screen_capture_bridge.dart';
import 'package:spy_love/app/core/network/screen_stream_client.dart';
import 'package:spy_love/app/modules/device_detail/models/screen_share_session.dart';
import 'package:spy_love/app/modules/device_detail/repositories/screen_share_repository.dart';

/// Monitored-device side of consent-scoped live screen sharing.
///
/// Consent model (all three required, matching the product's consent-first
/// design — there is deliberately no covert path):
///   1. an active, revocable `screen` consent scope (enforced server-side on
///      request/start and on the WS consumer), and sharing must not be paused;
///   2. the OS MediaProjection grant, prompted every time via
///      [ScreenCaptureBridge.startCapture];
///   3. a persistent on-device indicator — this service is a [ChangeNotifier]
///      so the always-mounted banner can show "Your screen is being shared",
///      and the OS screen-cast icon is shown by the foreground capture service.
///
/// The service polls the backend for a pending request from the paired monitor;
/// it only begins capture after the user-facing OS grant succeeds.
class ScreenShareService extends ChangeNotifier {
  ScreenShareService(this._repo);

  final ScreenShareRepository _repo;

  ScreenStreamClient? _stream;
  StreamSubscription<Map<String, dynamic>>? _frameSub;
  Timer? _pollTimer;
  String? _deviceId;

  ScreenShareSession? _session;
  bool _sharing = false;
  bool _supported = true;

  bool get isSharing => _sharing;
  bool get isSupported => _supported;
  ScreenShareSession? get session => _session;

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
    final deviceId = _deviceId;
    if (deviceId == null || _sharing) return;
    final result = await _repo.pendingForOwner(deviceId);
    if (result.isRight) return;
    final pending = result.left;
    if (pending == null) return;
    if (pending.status == 'requested') {
      await accept(pending);
    }
  }

  /// Accepts a pending request: prompts the OS grant, starts capture, and
  /// begins streaming frames. Returns false if unsupported or the user denies
  /// the OS prompt (in which case the request is declined server-side).
  Future<bool> accept(ScreenShareSession pending) async {
    _supported = await ScreenCaptureBridge.isSupported();
    if (!_supported) {
      await _repo.denySession(pending.id);
      notifyListeners();
      return false;
    }

    final granted = await ScreenCaptureBridge.startCapture();
    if (!granted) {
      await _repo.denySession(pending.id);
      return false;
    }

    final started = await _repo.startSession(pending.id);
    if (started.isRight) {
      await ScreenCaptureBridge.stopCapture();
      return false;
    }
    _session = started.left;

    final stream = _stream;
    if (stream == null) {
      await _teardown(reason: 'no_transport');
      return false;
    }

    final connected = await stream.connect(
      _session!.wsPath,
      onSignal: (signal) {
        if (signal['signal'] == 'ended' || signal['signal'] == 'paused') {
          unawaited(stop(reason: signal['signal'] as String?));
        }
      },
      onClosed: () => unawaited(stop(reason: 'socket_closed')),
    );
    if (!connected) {
      await _teardown(reason: 'connect_failed');
      return false;
    }

    _frameSub = ScreenCaptureBridge.frameStream.listen((frame) {
      final image = frame['image'];
      if (image is! String) return;
      stream.sendFrame(
        jpegBase64: image,
        width: (frame['w'] as num?)?.toInt() ?? 0,
        height: (frame['h'] as num?)?.toInt() ?? 0,
      );
    });

    _sharing = true;
    notifyListeners();
    return true;
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

  Future<void> _teardown({String? reason}) async {
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
    unawaited(_frameSub?.cancel());
    unawaited(_stream?.close());
    super.dispose();
  }
}

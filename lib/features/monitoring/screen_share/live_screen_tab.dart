import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/screen_stream_client.dart';
import 'package:spy_love/core/storage/token_storage.dart';
import 'package:spy_love/features/monitoring/screen_share/live_screen_controller.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_repository.dart';

/// Monitor-side "Live screen" tab. Requests a consent-gated live view of the
/// monitored device and renders relayed JPEG frames. Read-only.
class LiveScreenTab extends StatefulWidget {
  const LiveScreenTab({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<LiveScreenTab> createState() => _LiveScreenTabState();
}

class _LiveScreenTabState extends State<LiveScreenTab> {
  late final LiveScreenController _controller;

  @override
  void initState() {
    super.initState();
    final tokens = context.read<TokenStorage>();
    final repo = ScreenShareRepository(context.read<ApiService>());
    _controller = LiveScreenController(repo, ScreenStreamClient(tokens));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LiveScreenController>.value(
      value: _controller,
      child: Consumer<LiveScreenController>(
        builder: (context, controller, _) {
          return Column(
            children: [
              Expanded(child: _buildStage(controller)),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildControls(controller),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStage(LiveScreenController controller) {
    final frame = controller.frame;
    if (frame != null && controller.status == LiveScreenStatus.live) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Image.memory(frame, gaplessPlayback: true, fit: BoxFit.contain),
      );
    }

    final (icon, message) = switch (controller.status) {
      LiveScreenStatus.idle => (
        Icons.screen_share_outlined,
        'Request a live view of this device\'s screen.\n'
            'The owner must approve it and their screen will show a '
            'sharing indicator the whole time.',
      ),
      LiveScreenStatus.requesting => (
        Icons.hourglass_empty,
        'Sending request\u2026',
      ),
      LiveScreenStatus.waiting => (
        Icons.phonelink_ring_outlined,
        'Waiting for the device owner to approve and start sharing\u2026',
      ),
      LiveScreenStatus.live => (Icons.cast_connected, 'Live'),
      LiveScreenStatus.ended => (
        Icons.cast_outlined,
        'The live session has ended.',
      ),
      LiveScreenStatus.error => (
        Icons.error_outline,
        controller.error ?? 'Could not start the live screen session.',
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
          ],
        ),
      ),
    );
  }

  Widget _buildControls(LiveScreenController controller) {
    final streaming = controller.isStreaming;
    return Row(
      children: [
        if (controller.status == LiveScreenStatus.live)
          Expanded(
            child: Text(
              'Live \u2022 ${controller.frameCount} frames',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          const Spacer(),
        if (streaming)
          FilledButton.tonalIcon(
            onPressed: controller.stop,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          )
        else
          FilledButton.icon(
            onPressed: () => controller.start(widget.deviceId),
            icon: const Icon(Icons.screen_share),
            label: const Text('Request live screen'),
          ),
      ],
    );
  }
}

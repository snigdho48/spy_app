import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/screen_stream_client.dart';
import 'package:spy_love/core/storage/token_storage.dart';
import 'package:spy_love/features/monitoring/screen_share/live_screen_controller.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_control_mapping.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_repository.dart';

/// Monitor-side "Live screen" tab. Starts a consent-scoped live view of the
/// monitored device (silent — no per-session approval) and renders JPEG frames.
/// Remote control is offered separately and stays blocked until the paired
/// device explicitly approves.
class LiveScreenTab extends StatefulWidget {
  const LiveScreenTab({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<LiveScreenTab> createState() => _LiveScreenTabState();
}

class _LiveScreenTabState extends State<LiveScreenTab> {
  late final LiveScreenController _controller;
  Offset? _panStart;

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
    if (frame != null &&
        (controller.status == LiveScreenStatus.live ||
            controller.status == LiveScreenStatus.waiting)) {
      return Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                Widget preview = Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Image.memory(
                    frame,
                    gaplessPlayback: true,
                    fit: BoxFit.contain,
                  ),
                );
                if (controller.controlApproved) {
                  preview = GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final mapped = mapNormalizedPointer(
                        local: details.localPosition,
                        viewSize: viewSize,
                        imageWidth: controller.frameWidth,
                        imageHeight: controller.frameHeight,
                      );
                      if (mapped != null) {
                        controller.sendControlTap(mapped.dx, mapped.dy);
                      }
                    },
                    onLongPressStart: (details) {
                      final mapped = mapNormalizedPointer(
                        local: details.localPosition,
                        viewSize: viewSize,
                        imageWidth: controller.frameWidth,
                        imageHeight: controller.frameHeight,
                      );
                      if (mapped != null) {
                        controller.sendControlLongPress(mapped.dx, mapped.dy);
                      }
                    },
                    onPanStart: (details) {
                      _panStart = details.localPosition;
                    },
                    onPanEnd: (details) {
                      final start = _panStart;
                      if (start == null) return;
                      _panStart = null;
                      final from = mapNormalizedPointer(
                        local: start,
                        viewSize: viewSize,
                        imageWidth: controller.frameWidth,
                        imageHeight: controller.frameHeight,
                      );
                      final to = mapNormalizedPointer(
                        local: details.localPosition,
                        viewSize: viewSize,
                        imageWidth: controller.frameWidth,
                        imageHeight: controller.frameHeight,
                      );
                      if (from == null || to == null) return;
                      if ((details.localPosition - start).distance < 24) return;
                      controller.sendControlSwipe(
                        from.dx,
                        from.dy,
                        to.dx,
                        to.dy,
                      );
                    },
                    child: preview,
                  );
                }
                return preview;
              },
            ),
          ),
          if (controller.isStale)
            const Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _StatusBanner(
                icon: Icons.hourglass_top,
                label: 'Waiting for a new frame\u2026',
              ),
            ),
          if (controller.controlApproved)
            const Positioned(
              top: 12,
              right: 12,
              child: _StatusBanner(
                icon: Icons.touch_app,
                label: 'Control on',
              ),
            ),
        ],
      );
    }

    final (icon, message) = switch (controller.status) {
      LiveScreenStatus.idle => (
        Icons.screen_share_outlined,
        'View this device\'s screen live.\n'
            'Requires the screen consent scope on that device. '
            'Android still shows the system capture dialog on the paired phone.',
      ),
      LiveScreenStatus.requesting => (Icons.hourglass_empty, 'Starting\u2026'),
      LiveScreenStatus.connecting => (
        Icons.hourglass_top,
        'Opening the live connection\u2026',
      ),
      LiveScreenStatus.waiting => (
        Icons.hourglass_top,
        controller.slowWait
            ? 'Still waiting for the first frame. The paired device may be '
                'offline or sitting on the system screen-capture prompt.'
            : 'Connected. Waiting for the paired device to start sending '
                'the screen\u2026',
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
            if (controller.status == LiveScreenStatus.connecting &&
                controller.slowWait) ...[
              const SizedBox(height: 12),
              Text(
                'This is taking longer than usual. The paired device may be offline.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls(LiveScreenController controller) {
    final streaming = controller.isStreaming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (controller.status == LiveScreenStatus.live)
              Expanded(
                child: Text(
                  'Live \u2022 ${controller.frameCount} frames',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else if (controller.status == LiveScreenStatus.waiting)
              Expanded(
                child: Text(
                  'Waiting for screen\u2026',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              const Spacer(),
            if (streaming) ...[
              _controlButton(controller),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: controller.stop,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ] else
              FilledButton.icon(
                onPressed: () => controller.start(widget.deviceId),
                icon: const Icon(Icons.screen_share),
                label: Text(
                  controller.status == LiveScreenStatus.ended ||
                          controller.status == LiveScreenStatus.error
                      ? 'Start again'
                      : 'Start live screen',
                ),
              ),
          ],
        ),
        if (controller.controlMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            controller.controlMessage!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (controller.controlApproved) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.sendControlNav('back'),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.sendControlNav('home'),
                  child: const Text('Home'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.sendControlNav('recents'),
                  child: const Text('Recents'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _controlButton(LiveScreenController controller) {
    return switch (controller.controlStatus) {
      LiveScreenControlStatus.approved => FilledButton.tonalIcon(
        onPressed: controller.endControl,
        icon: const Icon(Icons.pan_tool_alt),
        label: const Text('Stop control'),
      ),
      LiveScreenControlStatus.requesting ||
      LiveScreenControlStatus.awaitingApproval => FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top),
        label: const Text('Waiting to approve'),
      ),
      LiveScreenControlStatus.denied ||
      LiveScreenControlStatus.none => FilledButton.tonalIcon(
        onPressed: controller.status == LiveScreenStatus.live
            ? controller.requestControl
            : null,
        icon: const Icon(Icons.touch_app_outlined),
        label: const Text('Request control'),
      ),
    };
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

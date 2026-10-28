import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_service.dart';

/// Always-mounted, monitored-device banner shown while the screen is being
/// shared live. This is a hard requirement of the consent-first design: the
/// device owner must always see that their screen is visible to the monitor
/// (in addition to the OS MediaProjection screen-cast indicator).
///
/// Mounted in the global [MaterialApp] builder stack; it renders nothing unless
/// [ScreenShareService.isSharing] is true, so it is inert on monitor devices.
class ScreenSharingIndicator extends StatelessWidget {
  const ScreenSharingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final sharing = context.watch<ScreenShareService>().isSharing;
    if (!sharing) return const SizedBox.shrink();

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.screen_share, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Your screen is being shared live',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => context.read<ScreenShareService>().stop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('STOP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

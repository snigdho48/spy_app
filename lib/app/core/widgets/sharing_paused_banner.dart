import 'package:flutter/material.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/modules/dashboard/models/device_model.dart';

/// Read-only banner for monitors when the owner has paused sharing.
class SharingPausedBanner extends StatelessWidget {
  const SharingPausedBanner({super.key, required this.sharing});

  final SharingState sharing;

  String _countdown() {
    final seconds = sharing.resumesInSeconds ??
        (sharing.pausedUntil == null
            ? 0
            : sharing.pausedUntil!
                .toUtc()
                .difference(DateTime.now().toUtc())
                .inSeconds);
    final safe = seconds < 0 ? 0 : seconds;
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!sharing.paused) return const SizedBox.shrink();

    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        color: tokens.warningSoft,
        elevated: false,
        child: Row(
          children: [
            Icon(Icons.pause_circle_filled, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sharing paused by device owner',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    'Telemetry uploads are stopped. Resumes in ${_countdown()}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

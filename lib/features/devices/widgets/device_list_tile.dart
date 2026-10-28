import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/features/devices/widgets/device_avatar.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';
import 'package:spy_love/features/devices/models/device_home_snapshot.dart';
import 'package:spy_love/features/devices/models/device_model.dart';

class DeviceListTile extends StatelessWidget {
  const DeviceListTile({
    super.key,
    required this.device,
    required this.onTap,
    this.snapshot,
    this.actionLabel = 'View',
  });

  final DeviceModel device;
  final VoidCallback onTap;
  final DeviceHomeSnapshot? snapshot;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final platform = device.platform.isEmpty
        ? 'Device'
        : '${device.platform[0].toUpperCase()}${device.platform.substring(1)}';
    final lowBattery =
        snapshot?.batteryPercent != null && snapshot!.batteryPercent! <= 20;

    return AppCard(
      onTap: onTap,
      semanticLabel: 'Device ${device.name}, $platform. $actionLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DeviceAvatar(device: device),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      platform,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: StatusBadge.device(device.status)),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: actionLabel,
                child: SizedBox(
                  width: AppSpacing.touchMin,
                  height: AppSpacing.touchMin,
                  child: Icon(Icons.chevron_right, color: tokens.secondaryText),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 320;
              final battery = _SnapshotChip(
                icon: lowBattery
                    ? Icons.battery_alert_outlined
                    : Icons.battery_std_outlined,
                label: snapshot?.batteryCaption ?? 'Battery syncing…',
                color: lowBattery ? tokens.revokeText : tokens.consented,
                background: lowBattery
                    ? tokens.dangerSoft
                    : tokens.surfaceContainerLow,
              );
              final location = _SnapshotChip(
                icon: Icons.location_on_outlined,
                label: snapshot == null
                    ? 'Location syncing…'
                    : snapshot!.geofenceCaption,
                color: theme.colorScheme.primary,
                background: tokens.surfaceContainerLow,
              );
              if (stack) {
                return Column(
                  children: [
                    battery,
                    const SizedBox(height: AppSpacing.xs),
                    location,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: battery),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: location),
                ],
              );
            },
          ),
          if (device.lastSeenAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Synced ${TimestampLabel.relative(device.lastSeenAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SnapshotChip extends StatelessWidget {
  const _SnapshotChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

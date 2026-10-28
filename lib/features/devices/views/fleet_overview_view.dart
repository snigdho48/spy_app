import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/routes.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/controllers/fleet_overview_controller.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/models/device_overview.dart';
import 'package:spy_love/shared/widgets/adaptive_metric_row.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/metric_card.dart';
import 'package:spy_love/shared/widgets/section_header.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';

/// Multi-device dashboard: a summary strip plus one status card per accessible
/// device (online/last-seen, battery, unread alerts, last known location).
class FleetOverviewView extends StatelessWidget {
  const FleetOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FleetOverviewController>();
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final summary = controller.summary;

    if (controller.isLoading && controller.overviews.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('All devices')),
        body: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LoadingSkeleton(lines: 6),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('All devices')),
      body: AppPage(
        onRefresh: controller.refresh,
        children: [
          Text('Fleet overview', style: theme.textTheme.headlineSmall),
          Text(
            '${summary.totalDevices} device${summary.totalDevices == 1 ? '' : 's'} · '
            '${summary.onlineDevices} online',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryStrip(summary: summary),
          const SizedBox(height: AppSpacing.lg),
          if (controller.errorMessage.isNotEmpty &&
              controller.overviews.isEmpty)
            ErrorState(
              message: controller.errorMessage,
              onRetry: controller.load,
            )
          else if (controller.overviews.isEmpty)
            const EmptyState(
              icon: Icons.devices_other_outlined,
              title: 'No devices yet',
              message:
                  'Pair a phone to see its status, battery, alerts and location here.',
            )
          else ...[
            const SectionHeader(title: 'Devices'),
            const SizedBox(height: AppSpacing.sm),
            ...controller.overviews.map(
              (overview) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _DeviceStatusCard(overview: overview),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final FleetSummary summary;

  @override
  Widget build(BuildContext context) {
    return AdaptiveMetricRow(
      children: [
        MetricCard(
          label: 'Devices',
          value: '${summary.totalDevices}',
          caption: '${summary.onlineDevices} online now',
          icon: Icons.devices_outlined,
          badge: summary.onlineDevices > 0 ? 'Live' : null,
          badgeTone: StatusTone.success,
        ),
        MetricCard(
          label: 'Unread alerts',
          value: '${summary.totalUnreadAlerts}',
          caption: summary.totalUnreadAlerts == 0
              ? 'All caught up'
              : 'Across all devices',
          icon: Icons.notifications_active_outlined,
          badge: summary.totalUnreadAlerts > 0
              ? '${summary.totalUnreadAlerts}'
              : null,
          badgeTone: StatusTone.warning,
        ),
        MetricCard(
          label: 'Critical',
          value: '${summary.criticalAlerts}',
          caption: summary.hasCritical ? 'Needs attention' : 'None flagged',
          icon: Icons.priority_high_rounded,
          badge: summary.hasCritical ? 'Critical' : null,
          badgeTone: StatusTone.danger,
        ),
      ],
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({required this.overview});

  final DeviceOverview overview;

  String get _semanticLabel {
    final device = overview.device;
    final parts = <String>[
      device.name,
      overview.isOnline ? 'online' : 'offline',
      if (overview.batteryPercent != null)
        'battery ${overview.batteryPercent}%',
      if (overview.unreadAlerts > 0)
        '${overview.unreadAlerts} unread alerts'
      else
        'no unread alerts',
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final device = overview.device;

    return AppCard(
      onTap: () => _open(context, device),
      semanticLabel: _semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusDot(online: overview.isOnline, paused: overview.isPaused),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      overview.isPaused
                          ? 'Sharing paused'
                          : overview.isOnline
                          ? 'Online'
                          : device.lastSeenAt != null
                          ? 'Last seen ${TimestampLabel.relative(device.lastSeenAt!)}'
                          : 'Offline',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (overview.unreadAlerts > 0)
                StatusBadge(
                  label: overview.unreadAlerts > 99
                      ? '99+'
                      : '${overview.unreadAlerts}',
                  tone: overview.criticalAlerts > 0
                      ? StatusTone.danger
                      : StatusTone.warning,
                  showDot: false,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _Metric(
                icon: overview.batteryCharging == true
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_std_rounded,
                label: overview.batteryPercent != null
                    ? '${overview.batteryPercent}%'
                    : '—',
              ),
              _Metric(
                icon: Icons.location_on_outlined,
                label: overview.accessDenied
                    ? 'View only'
                    : overview.lastLocation?.displayLabel ?? 'No location',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, DeviceModel device) async {
    await AppNavigator.toNamed(AppRoutes.deviceDetail, arguments: device);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tokens.secondaryText),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online, required this.paused});

  final bool online;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = paused
        ? tokens.secondaryText
        : online
        ? tokens.consented
        : tokens.secondaryText.withValues(alpha: 0.5);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

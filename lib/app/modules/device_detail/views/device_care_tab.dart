import 'package:flutter/material.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_button.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/app_states.dart';
import 'package:spy_love/app/core/widgets/sharing_paused_banner.dart';
import 'package:spy_love/app/core/widgets/status_badge.dart';
import 'package:spy_love/app/core/widgets/timestamp_label.dart';
import 'package:spy_love/app/modules/device_detail/controllers/device_detail_controller.dart';
import 'package:spy_love/app/modules/device_detail/models/device_event_model.dart';
import 'package:spy_love/app/modules/device_detail/models/location_point.dart';

/// Battery / network / app usage / device info + Stitch diagnostics chrome.
class DeviceCareTab extends StatelessWidget {
  const DeviceCareTab({super.key, required this.controller});

  final DeviceDetailController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    if (controller.isLoadingEvents &&
        controller.batteryEvents.isEmpty &&
        controller.networkEvents.isEmpty &&
        controller.appUsageEvents.isEmpty &&
        controller.deviceInfoEvents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LoadingSkeleton(lines: 4),
      );
    }

    final battery = controller.latestBattery;
    final network = controller.latestNetwork;
    final deviceInfo = controller.latestDeviceInfo;
    final latestLoc = controller.latestLocation;
    final maskedImei = _maskedImei(deviceInfo);

    return ListView(
      padding: context.pagePadding,
      children: [
        Text('Device care', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Battery, network, app activity, and hardware status from consented scopes.',
          style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
        ),
        const SizedBox(height: AppSpacing.md),
        _SafeZoneStrip(location: latestLoc),
        const SizedBox(height: AppSpacing.sm),
        _CareCard(
          icon: Icons.battery_charging_full,
          title: 'Battery & power',
          badge: battery == null ? 'No data' : 'Live vital',
          tone: battery == null ? StatusTone.neutral : StatusTone.success,
          lines: battery == null
              ? const ['Waiting for battery.status events with battery consent.']
              : [
                  _payloadLine(battery, 'level', 'percent', suffix: '%'),
                  _payloadLine(battery, 'charging', 'is_charging', prefix: 'Charging: '),
                  'Updated ${TimestampLabel.format(battery.eventTimestamp)}',
                ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _CareCard(
          icon: Icons.wifi,
          title: 'Network & Wi‑Fi',
          badge: network == null ? 'No data' : 'SSL guard',
          tone: network == null ? StatusTone.neutral : StatusTone.info,
          lines: network == null
              ? const ['Waiting for network.status events with network consent.']
              : [
                  _payloadLine(network, 'type', 'connection_type', prefix: 'Type: '),
                  _payloadLine(network, 'ssid', 'wifi_ssid', prefix: 'SSID: '),
                  'Updated ${TimestampLabel.format(network.eventTimestamp)}',
                ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _CareCard(
          icon: Icons.apps,
          title: 'App activity',
          badge: controller.appUsageEvents.isEmpty ? 'No data' : 'Daily summary',
          tone: controller.appUsageEvents.isEmpty
              ? StatusTone.neutral
              : StatusTone.success,
          lines: controller.appUsageEvents.isEmpty
              ? const [
                  'Waiting for app_usage.snapshot events with app usage consent.',
                ]
              : controller.appUsageEvents.take(4).map((e) {
                  final name =
                      e.payload['app_name'] ?? e.payload['package'] ?? 'App';
                  final mins =
                      e.payload['duration_minutes'] ?? e.payload['minutes'];
                  return mins == null ? '$name' : '$name · ${mins}m';
                }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        _CareCard(
          icon: Icons.phonelink_setup,
          title: 'Device info',
          badge: deviceInfo == null ? 'No data' : 'Hardware status',
          tone: deviceInfo == null ? StatusTone.neutral : StatusTone.info,
          lines: deviceInfo == null
              ? const [
                  'Waiting for device_info.snapshot events with device info consent.',
                ]
              : [
                  _payloadLine(deviceInfo, 'model', 'device_model', prefix: 'Model: '),
                  _payloadLine(deviceInfo, 'os', 'os_version', prefix: 'OS: '),
                  _payloadLine(deviceInfo, 'manufacturer', 'brand', prefix: 'Maker: '),
                  'IMEI: $maskedImei',
                  'Updated ${TimestampLabel.format(deviceInfo.eventTimestamp)}',
                ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Mutual governance', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        SharingPausedBanner(sharing: controller.sharing),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pause sharing',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                controller.sharing.paused
                    ? 'The monitored person paused uploads. Consent stays active; new telemetry will resume when they end the pause.'
                    : 'Only the monitored person can pause or resume from Account on their device. You can see pause state here and on Overview.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Revoke consent & disconnect',
          icon: Icons.link_off,
          variant: AppButtonVariant.destructive,
          onPressed: controller.isActionInProgress
              ? null
              : controller.disconnectDevice,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Disconnect opens the soft-remove confirm. Check purge for permanent delete.',
          style: theme.textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
        ),
      ],
    );
  }

  static String _maskedImei(DeviceEventModel? info) {
    if (info == null) return '———— — —';
    final raw = (info.payload['imei'] ??
            info.payload['device_id'] ??
            info.payload['serial'] ??
            '')
        .toString()
        .replaceAll(RegExp(r'\s'), '');
    if (raw.isEmpty) return '———— — —';
    if (raw.length <= 4) return '**** $raw';
    final tail = raw.substring(raw.length - 4);
    return '———— $tail';
  }

  static String _payloadLine(
    DeviceEventModel event,
    String a,
    String b, {
    String prefix = '',
    String suffix = '',
  }) {
    final value = event.payload[a] ?? event.payload[b];
    if (value == null || '$value'.isEmpty) return '$prefix—';
    return '$prefix$value$suffix';
  }
}

class _SafeZoneStrip extends StatelessWidget {
  const _SafeZoneStrip({this.location});

  final LocationPoint? location;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final hasLoc = location != null;
    final accuracy = location?.accuracyM;

    return AppCard(
      color: tokens.primarySoft,
      elevated: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.18),
                  tokens.surfaceContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.shield_outlined,
                    size: 40,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  top: AppSpacing.md,
                  child: StatusBadge(
                    label: hasLoc ? 'Safe zone ping' : 'No location yet',
                    tone: hasLoc ? StatusTone.success : StatusTone.neutral,
                    pulse: hasLoc,
                  ),
                ),
                if (accuracy != null)
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: StatusBadge(
                      label: 'Accurate to ${accuracy.round()}m',
                      tone: StatusTone.info,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLoc
                      ? location!.displayLabel
                      : 'Waiting for a consented location fix',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  hasLoc
                      ? [
                          if (location!.placeName != null ||
                              location!.zoneName != null)
                            '${location!.lat.toStringAsFixed(4)}, ${location!.lng.toStringAsFixed(4)}',
                          'Last ping ${TimestampLabel.relative(location!.timestamp)}',
                        ].join(' · ')
                      : 'Grant location consent on the monitored device to show the safe-zone strip.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CareCard extends StatelessWidget {
  const _CareCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.tone,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final String badge;
  final StatusTone tone;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              StatusBadge(
                label: badge,
                tone: tone,
                pulse: tone == StatusTone.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

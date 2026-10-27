import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/consent_row.dart';
import 'package:spy_love/shared/widgets/event_list_tile.dart';
import 'package:spy_love/shared/widgets/metric_card.dart';
import 'package:spy_love/features/devices/widgets/sharing_paused_banner.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';
import 'package:spy_love/features/devices/controllers/device_detail_controller.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';
import 'package:spy_love/features/devices/views/activity_feed_tab.dart';
import 'package:spy_love/features/devices/views/device_care_tab.dart';
import 'package:spy_love/features/devices/views/event_detail_view.dart';
import 'package:spy_love/features/monitoring/screen_share/live_screen_tab.dart';
import 'package:spy_love/features/devices/views/location_tab_view.dart';
import 'package:spy_love/features/devices/views/sim_tab_view.dart';
import 'package:spy_love/features/consent/models/consent_scope.dart';
import 'package:spy_love/app/routes.dart';

class DeviceDetailView extends StatelessWidget {
  const DeviceDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<DeviceDetailController>();
    final platform = controller.device.platform.isEmpty
        ? 'Device'
        : '${controller.device.platform[0].toUpperCase()}${controller.device.platform.substring(1)}';
    final tokens = context.tokens;

    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(controller.device.name),
              Text(
                '● CONSENTED LINK',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.consented,
                    ),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Overview'),
              const Tab(text: 'Care'),
              const Tab(text: 'SIM'),
              const Tab(text: 'Location'),
              const Tab(text: 'Calls'),
              const Tab(text: 'SMS'),
              const Tab(text: 'Messages'),
              const Tab(text: 'Live screen'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Center(
                child: StatusBadge.device(controller.device.status),
              ),
            ),
            Consumer<DeviceDetailController>(
              builder: (context, controller, _) {
                if (controller.isActionInProgress) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'disconnect':
                        controller.disconnectDevice();
                      case 'delete':
                        controller.deleteDevice();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'disconnect',
                      child: Text('Disconnect'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete device'),
                    ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: controller.refreshEvents,
            ),
          ],
        ),
        body: Consumer<DeviceDetailController>(
          builder: (context, controller, _) {
            if (controller.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: LoadingSkeleton(lines: 5),
              );
            }
            if (controller.errorMessage.isNotEmpty &&
                controller.consent == null) {
              return ErrorState(
                message: controller.errorMessage,
                onRetry: controller.loadDetail,
              );
            }
            return TabBarView(
              children: [
                _OverviewTab(controller: controller, platform: platform),
                DeviceCareTab(controller: controller),
                const SimTabView(),
                const LocationTabView(),
                ActivityFeedTab(
                  kind: ActivityFeedKind.calls,
                  events: controller.calls,
                  isLoading: controller.isLoadingEvents,
                  onOpen: (event) => _openEvent(controller, event),
                ),
                ActivityFeedTab(
                  kind: ActivityFeedKind.sms,
                  events: controller.sms,
                  isLoading: controller.isLoadingEvents,
                  companionCount: controller.uniqueSmsSenders,
                  onOpen: (event) => _openEvent(controller, event),
                ),
                ActivityFeedTab(
                  kind: ActivityFeedKind.messages,
                  events: controller.messages,
                  isLoading: controller.isLoadingEvents,
                  companionCount: controller.uniqueMessageApps,
                  onOpen: (event) => _openEvent(controller, event),
                ),
                LiveScreenTab(deviceId: controller.device.id),
              ],
            );
          },
        ),
      ),
    );
  }

  static void _openEvent(
    DeviceDetailController controller,
    DeviceEventModel event,
  ) {
    AppNavigator.toNamed(
      AppRoutes.eventDetail,
      arguments: {
        'event': event,
        'deviceName': controller.device.name,
        'consentActive': controller.consent != null,
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.controller, required this.platform});

  final DeviceDetailController controller;
  final String platform;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final scopes = (controller.consent?['scopes'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toSet();
    final online = controller.device.status.toLowerCase() == 'active';
    final lastSeen = controller.device.lastSeenAt;
    final battery = controller.latestBattery;
    final network = controller.latestNetwork;
    final batteryLevel = battery?.payload['level'] ?? battery?.payload['percent'];
    final ssid = network?.payload['ssid'] ?? network?.payload['wifi_ssid'];

    return RefreshIndicator(
      onRefresh: controller.refreshEvents,
      child: ListView(
        padding: context.pagePadding,
        children: [
          SharingPausedBanner(sharing: controller.sharing),
          AppCard(
            color: tokens.primarySoft,
            elevated: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: tokens.surface,
                      child: Icon(Icons.smartphone, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(controller.device.name, style: theme.textTheme.titleMedium),
                          Text(
                            '$platform · Battery ${batteryLevel ?? '—'}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: tokens.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge.device(controller.device.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  lastSeen == null
                      ? (online ? 'Live synced just now' : 'Waiting for heartbeat')
                      : 'Live synced ${TimestampLabel.relative(lastSeen)}',
                  style: theme.textTheme.labelMedium,
                ),
                if (ssid != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Wi‑Fi · $ssid',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Battery',
                  value: batteryLevel == null ? '—' : '$batteryLevel%',
                  caption: 'Power health',
                  icon: Icons.bolt_outlined,
                  badge: batteryLevel != null ? 'Live' : null,
                  badgeTone: StatusTone.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricCard(
                  label: 'Network',
                  value: ssid == null ? '—' : '$ssid',
                  caption: 'Secure link',
                  icon: Icons.wifi,
                  badge: ssid != null ? 'On' : null,
                  badgeTone: StatusTone.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricCard(
                  label: 'Sync',
                  value: online ? 'Live' : 'Idle',
                  caption: lastSeen == null
                      ? 'Waiting'
                      : TimestampLabel.relative(lastSeen),
                  icon: Icons.sync,
                  badge: online ? 'E2E' : null,
                  badgeTone: StatusTone.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Events',
                  value: '${controller.allEvents.length}',
                  caption: 'Recent activity',
                  icon: Icons.timeline,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricCard(
                  label: 'Consent',
                  value: '${scopes.length}',
                  caption: scopes.isEmpty ? 'None granted' : 'Scopes active',
                  icon: Icons.verified_user_outlined,
                  badge: scopes.isEmpty ? null : 'OK',
                  badgeTone: StatusTone.success,
                ),
              ),
            ],
          ),
          if (controller.ownerEmail != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device owner', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (controller.ownerName?.isNotEmpty == true)
                        controller.ownerName!,
                      controller.ownerEmail!,
                    ].join('\n'),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Consent scopes', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < ConsentScope.all.length; i++) ...[
                  if (i > 0) const Divider(),
                  Builder(
                    builder: (context) {
                      final scope = ConsentScope.all[i];
                      final granted = scopes.contains(scope.id);
                      return ConsentRow(
                        title: scope.label,
                        subtitle: scope.description,
                        enabled: granted,
                        showSwitch: false,
                        statusLabel: granted ? 'Consented' : 'Not granted',
                        statusTone: granted
                            ? StatusTone.success
                            : StatusTone.warning,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Consent is set at pairing. Disconnect or delete to revoke all scopes for this device.',
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Recent activity', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (controller.isLoadingEvents && controller.allEvents.isEmpty)
            const LoadingSkeleton(lines: 3)
          else if (controller.allEvents.isEmpty)
            const EmptyState(
              title: 'No events yet',
              message:
                  'Data syncs from the monitored device every few minutes while sharing is active.',
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: controller.allEvents.take(8).map((event) {
                  final meta = EventPresentation.from(event);
                  return EventListTile(
                    title: meta.title,
                    preview: meta.preview,
                    timestamp: event.eventTimestamp,
                    icon: meta.icon,
                    onTap: () => DeviceDetailView._openEvent(controller, event),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text('Device Management', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Actions honor mutual notification protocols',
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: AppSpacing.sm),
          Builder(
            builder: (context) {
              final busy = controller.isActionInProgress;
              return Column(
                children: [
                  AppButton(
                    label: 'Disconnect & Revoke Pairing',
                    icon: Icons.link_off,
                    variant: AppButtonVariant.soft,
                    loading: busy,
                    onPressed: busy ? null : controller.disconnectDevice,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Delete Device & Purge Historical Logs',
                    icon: Icons.delete_outline,
                    variant: AppButtonVariant.destructive,
                    loading: busy,
                    onPressed: busy ? null : controller.deleteDevice,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Disconnect opens the soft-remove confirm. Purge permanently deletes historical telemetry.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

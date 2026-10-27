import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/network/network_service.dart';
import 'package:spy_love/core/theme/app_colors.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/adaptive_metric_row.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/features/devices/widgets/device_list_tile.dart';
import 'package:spy_love/features/devices/widgets/family_circle_switcher.dart';
import 'package:spy_love/shared/widgets/metric_card.dart';
import 'package:spy_love/shared/widgets/section_header.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/devices/controllers/dashboard_controller.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/subscription/views/workspace_setup_card.dart';
import 'package:spy_love/app/routes.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onSeeDevices, required this.onPair});

  final VoidCallback onSeeDevices;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final auth = context.watch<AuthController>();
    final network = context.watch<NetworkService>();
    final tokens = context.tokens;
    final theme = Theme.of(context);

    final user = auth.user;
    final name = (user?.fullName.isNotEmpty == true)
        ? user!.fullName.split(' ').first
        : 'there';

    if (controller.isLoading && controller.devices.isEmpty) {
      return AppPage(
        children: [
          Text(
            'Spy Love · Home',
            style: theme.textTheme.headlineSmall,
          ),
          Text(
            '● MUTUAL TRANSPARENCY ACTIVE',
            style: theme.textTheme.labelSmall?.copyWith(color: tokens.consented),
          ),
          const SizedBox(height: AppSpacing.md),
          const HomeSkeleton(),
        ],
      );
    }

    return AppPage(
      onRefresh: controller.loadDevices,
      children: [
        Text('Spy Love · Home', style: theme.textTheme.headlineSmall),
        Text(
          '● MUTUAL TRANSPARENCY ACTIVE',
          style: theme.textTheme.labelSmall?.copyWith(color: tokens.consented),
        ),
        if (user != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hi $name',
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (!network.isConnected) ...[
          OfflineBanner(onRetry: () async {
            await network.refreshStatus();
            await controller.loadDevices();
          }),
          const SizedBox(height: AppSpacing.md),
        ],
        const WorkspaceSetupCard(),
        const FamilyCircleCard(),
        const SizedBox(height: AppSpacing.md),
        _HeroCard(
          activeCount: controller.activeDeviceCount,
          needsWorkspace: user?.needsWorkspace ?? false,
          online: network.isConnected,
          attentionCount: controller.attentionCount,
        ),
        const SizedBox(height: AppSpacing.md),
        AdaptiveMetricRow(
          children: [
            AppButton(
              label: '+ Pair new phone',
              icon: Icons.add,
              onPressed: onPair,
            ),
            AppButton(
              label: 'View audit ledger',
              icon: Icons.menu_book_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => AppNavigator.toNamed(AppRoutes.audit),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _MetricGrid(controller: controller, onSeeDevices: onSeeDevices),
        if (!controller.permissions.allGranted) ...[
          const SizedBox(height: AppSpacing.md),
          _PermissionBanner(controller: controller),
        ],
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: 'Monitored Family Devices',
          action: TextButton(
            onPressed: onSeeDevices,
            child: Text(
              '${controller.activeDeviceCount} online',
              style: theme.textTheme.labelLarge,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _DevicePreview(
          controller: controller,
          onPair: onPair,
          offline: !network.isConnected,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: tokens.surfaceContainerLow,
          elevated: false,
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, color: tokens.consented),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Zero secret surveillance guarantee — sharing stays visible on both devices.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.controller, required this.onSeeDevices});

  final DashboardController controller;
  final VoidCallback onSeeDevices;

  @override
  Widget build(BuildContext context) {
    final consentPct = controller.devices.isEmpty
        ? 0
        : ((controller.activeDeviceCount / controller.devices.length) * 100).round();
    return Column(
      children: [
        AdaptiveMetricRow(
          children: [
            MetricCard(
              label: 'Active devices',
              value: '${controller.activeDeviceCount}',
              caption: controller.attentionCount == 0
                  ? 'All consented & synced'
                  : '${controller.attentionCount} need review',
              icon: Icons.phone_android_outlined,
              onTap: onSeeDevices,
              badge: controller.activeDeviceCount > 0 ? 'Live' : null,
              badgeTone: StatusTone.success,
            ),
            MetricCard(
              label: 'Consent status',
              value: controller.devices.isEmpty ? '—' : '$consentPct%',
              caption: controller.attentionCount == 0 ? 'Healthy' : 'Needs review',
              icon: Icons.verified_user_outlined,
              badge: controller.attentionCount == 0 ? 'Healthy' : 'Review',
              badgeTone: controller.attentionCount == 0
                  ? StatusTone.info
                  : StatusTone.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AdaptiveMetricRow(
          children: [
            MetricCard(
              label: 'Battery alerts',
              value: controller.attentionCount > 0 ? '${controller.attentionCount}' : '0',
              caption: controller.attentionCount == 0
                  ? 'No low-power flags'
                  : 'Devices need attention',
              icon: Icons.battery_alert_outlined,
              badge: controller.attentionCount == 0
                  ? null
                  : '${controller.attentionCount} Alert',
              badgeTone: StatusTone.danger,
            ),
            MetricCard(
              label: 'Geofence safe',
              value: controller.activeDeviceCount > 0 ? 'Safe' : '—',
              caption: 'Home · School zones',
              icon: Icons.location_on_outlined,
              badge: controller.activeDeviceCount > 0 ? 'In Zone' : null,
              badgeTone: StatusTone.success,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.activeCount,
    required this.needsWorkspace,
    required this.online,
    required this.attentionCount,
  });

  final int activeCount;
  final bool needsWorkspace;
  final bool online;
  final int attentionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final healthy = !needsWorkspace && online && attentionCount == 0;
    return AppCard(
      color: healthy ? tokens.successSoft : theme.colorScheme.primary,
      borderColor: healthy ? tokens.consented : theme.colorScheme.primary,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needsWorkspace
                ? 'CREATE A WORKSPACE'
                : healthy
                    ? 'MUTUAL CONSENT LEDGER HEALTHY'
                    : online
                        ? 'CONSENT REVIEW NEEDED'
                        : 'OFFLINE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: healthy ? tokens.consentedLabel : AppColors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$activeCount device${activeCount == 1 ? '' : 's'} sharing with consent',
            style: theme.textTheme.titleMedium?.copyWith(
              color: healthy ? tokens.primaryText : AppColors.white,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            needsWorkspace
                ? 'Set up a family or team workspace to start pairing.'
                : healthy
                    ? 'Monitored members can audit shared logs, revoke telemetry, or view active pings in real time.'
                    : online
                        ? 'Review devices that need re-consent or attention.'
                        : 'Showing last known device status',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: healthy
                  ? tokens.secondaryText
                  : AppColors.white.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final missing = controller.permissions.missingPermissions;
    return AppCard(
      color: tokens.warningSoft,
      borderColor: AppColors.warning.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permissions needed',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Grant Usage Access and Notification Listener so pairing and care telemetry work on this device.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
          ),
          const SizedBox(height: 8),
          ...missing.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• ${item.title}'),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Open permission setup',
            onPressed: () => AppNavigator.toNamed(AppRoutes.permissionSetup),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: controller.isRequestingPermissions
                ? 'Requesting…'
                : 'Grant runtime permissions',
            variant: AppButtonVariant.secondary,
            loading: controller.isRequestingPermissions,
            onPressed: controller.requestPermissions,
          ),
        ],
      ),
    );
  }
}

class _DevicePreview extends StatelessWidget {
  const _DevicePreview({
    required this.controller,
    required this.onPair,
    required this.offline,
  });

  final DashboardController controller;
  final VoidCallback onPair;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    if (controller.errorMessage.isNotEmpty) {
      final msg = controller.errorMessage;
      final networkish = offline ||
          msg.toLowerCase().contains('socket') ||
          msg.toLowerCase().contains('network') ||
          msg.toLowerCase().contains('connection');
      if (networkish) {
        return ConnectionErrorState(onRetry: controller.loadDevices);
      }
      final friendly = msg.toLowerCase().contains('tenant membership')
          ? 'No active workspace. Create a workspace, then refresh.'
          : msg;
      return ErrorState(message: friendly, onRetry: controller.loadDevices);
    }
    if (controller.devices.isEmpty) {
      return EmptyState(
        icon: Icons.phonelink_setup,
        title: 'No devices yet',
        message:
            'Pair a phone to see live status, location, and activity here.',
        actionLabel: 'Pair a device',
        onAction: onPair,
      );
    }

    return Column(
      children: [
        ...controller.devices.take(4).map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DeviceListTile(
                  device: device,
                  snapshot: controller.snapshotFor(device.id),
                  onTap: () => _openDevice(device),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _openDevice(DeviceModel device) async {
    final result = await AppNavigator.toNamed(
      AppRoutes.deviceDetail,
      arguments: device,
    );
    if (result != null) {
      await controller.loadDevices();
    }
  }
}

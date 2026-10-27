import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/core/navigation/app_navigator.dart';
import 'package:spy_love/app/core/network/network_service.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_button.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/app_page.dart';
import 'package:spy_love/app/core/widgets/app_states.dart';
import 'package:spy_love/app/core/widgets/device_list_tile.dart';
import 'package:spy_love/app/core/widgets/status_badge.dart';
import 'package:spy_love/app/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:spy_love/app/modules/dashboard/models/device_model.dart';
import 'package:spy_love/app/routes/app_routes.dart';

class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key, required this.onPair});

  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final network = context.watch<NetworkService>();
    return AppPage(
      onRefresh: controller.loadDevices,
      children: [
        const PageIntro(
          title: 'Devices',
          subtitle: 'Everyone sharing with mutual consent in your workspace',
        ),
        if (!network.isConnected) ...[
          OfflineBanner(
            onRetry: () async {
              await network.refreshStatus();
              await controller.loadDevices();
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppCard(
          color: context.tokens.successSoft,
          elevated: false,
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, color: context.tokens.consented),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consent status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${controller.activeDeviceCount} sharing active • ${controller.attentionCount == 0 ? 'no issues' : '${controller.attentionCount} need review'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.tokens.secondaryText,
                          ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: controller.attentionCount == 0 ? 'Consented' : 'Review',
                tone: controller.attentionCount == 0 ? StatusTone.success : StatusTone.warning,
                pulse: controller.attentionCount == 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (controller.isLoading && controller.devices.isEmpty)
          const LoadingSkeleton(lines: 4)
        else if (controller.errorMessage.isNotEmpty)
          ErrorState(
            message: controller.errorMessage,
            onRetry: controller.loadDevices,
          )
        else if (controller.devices.isEmpty)
          EmptyState(
            icon: Icons.devices_other_outlined,
            title: 'No devices yet',
            message: 'Pair with a 6-character code or QR. Both sides confirm consent before any data is shared.',
            actionLabel: 'Pair device',
            onAction: onPair,
          )
        else
          ...controller.devices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DeviceListTile(
                device: device,
                snapshot: controller.snapshotFor(device.id),
                onTap: () => _openDevice(controller, device),
              ),
            ),
          ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Pair device',
          icon: Icons.add,
          variant: AppButtonVariant.secondary,
          onPressed: onPair,
        ),
      ],
    );
  }

  Future<void> _openDevice(
    DashboardController controller,
    DeviceModel device,
  ) async {
    final result = await AppNavigator.toNamed(
      AppRoutes.deviceDetail,
      arguments: device,
    );
    if (result != null) await controller.loadDevices();
  }
}

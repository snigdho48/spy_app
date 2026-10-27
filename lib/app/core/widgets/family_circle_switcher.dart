import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/core/navigation/app_navigator.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_button.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/device_avatar.dart';
import 'package:spy_love/app/core/widgets/status_badge.dart';
import 'package:spy_love/app/modules/auth/controllers/auth_controller.dart';
import 'package:spy_love/app/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:spy_love/app/modules/dashboard/models/device_model.dart';
import 'package:spy_love/app/routes/app_routes.dart';

/// Stitch "Family Circle" workspace header + sheet.
/// Backend exposes create-workspace only (no multi-tenant switch API yet).
class FamilyCircleCard extends StatelessWidget {
  const FamilyCircleCard({super.key, this.onManage});

  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final dashboard = context.watch<DashboardController>();
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final user = auth.user;
    final name = user?.tenantName?.isNotEmpty == true
        ? user!.tenantName!
        : 'Family Circle';
    final maxDevices = user?.subscription?.maxDevices ?? 0;
    final used = dashboard.devices.length;
    final slotPct = maxDevices <= 0 ? 0.0 : (used / maxDevices).clamp(0.0, 1.0);

    return AppCard(
      onTap: onManage ?? () => showFamilyCircleSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleAvatarStack(devices: dashboard.devices),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      'Family Care Plan · $used device${used == 1 ? '' : 's'}',
                      style: theme.textTheme.labelMedium?.copyWith(color: tokens.secondaryText),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: AppButton(
                  label: 'Manage Circle',
                  icon: Icons.settings_outlined,
                  variant: AppButtonVariant.soft,
                  expand: false,
                  onPressed: onManage ?? () => showFamilyCircleSheet(context),
                ),
              ),
            ],
          ),
          if (maxDevices > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Mutual Encryption Guard',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${(slotPct * 100).round()}% Circle Slots Used',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Thin encryption track (always full — decorative Stitch chrome).
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: 1,
                minHeight: 3,
                backgroundColor: tokens.border,
                color: theme.colorScheme.primary.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: slotPct,
                minHeight: 14,
                backgroundColor: tokens.primarySoft,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleAvatarStack extends StatelessWidget {
  const _CircleAvatarStack({required this.devices});

  final List<DeviceModel> devices;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final shown = devices.take(3).toList();
    if (shown.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: tokens.primarySoft,
        child: Icon(Icons.groups_outlined, color: theme.colorScheme.primary),
      );
    }
    final width = 40.0 + (shown.length - 1) * 22.0;
    return SizedBox(
      width: width,
      height: 48,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 22.0,
              child: DeviceAvatar(device: shown[i], size: 40),
            ),
        ],
      ),
    );
  }
}

Future<void> showFamilyCircleSheet(BuildContext context) {
  final auth = context.read<AuthController>();
  final dashboard = context.read<DashboardController>();
  final user = auth.user;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetBorder),
    builder: (ctx) {
      final tokens = ctx.tokens;
      final theme = Theme.of(ctx);
      final name = user?.tenantName?.isNotEmpty == true
          ? user!.tenantName!
          : 'Your Family Circle';
      return Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.lg,
          bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Family Circle workspace', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Switching circles requires a workspace membership API. This build shows your active workspace only.',
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              color: tokens.primarySoft,
              elevated: false,
              child: Row(
                children: [
                  Icon(Icons.home_work_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium),
                        Text(
                          '${dashboard.devices.length} paired devices · ${user?.subscription?.planName ?? 'Free'}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  const StatusBadge(label: 'Active', tone: StatusTone.success, pulse: true),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Open Account & Circle settings',
              icon: Icons.settings_outlined,
              onPressed: () {
                Navigator.pop(ctx);
                AppNavigator.toNamed(AppRoutes.subscriptions);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Close',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    },
  );
}

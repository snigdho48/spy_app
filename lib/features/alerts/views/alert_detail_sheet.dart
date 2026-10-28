import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/routes.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/alerts/models/alert_model.dart';
import 'package:spy_love/features/devices/controllers/dashboard_controller.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';

Future<void> showAlertDetailSheet(BuildContext context, AlertModel alert) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _AlertDetailSheet(alert: alert),
  );
}

class _AlertDetailSheet extends StatelessWidget {
  const _AlertDetailSheet({required this.alert});

  final AlertModel alert;

  DeviceModel? _resolveDevice(BuildContext context) {
    final id = alert.deviceId;
    if (id == null) return null;
    final devices = context.read<DashboardController>().devices;
    for (final d in devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final device = _resolveDevice(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alert.type.icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  alert.title.isEmpty ? alert.typeLabel : alert.title,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              StatusBadge(
                label: alert.severity.label,
                tone: alert.severity.tone,
                showDot: false,
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: alert.typeLabel,
                tone: StatusTone.neutral,
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TimestampLabel(alert.createdAt, compact: false),
          if (alert.body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(alert.body, style: theme.textTheme.bodyMedium),
          ],
          if (alert.metadata.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Details', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            ...alert.metadata.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${e.key}: ${e.value}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (device != null)
            AppButton(
              label: 'Open ${device.name}',
              icon: Icons.open_in_new_rounded,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(
                  AppRoutes.deviceDetail,
                  arguments: device,
                );
              },
            )
          else
            AppButton(
              label: 'Close',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}

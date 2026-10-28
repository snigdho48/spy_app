import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_colors.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/models/telemetry_model.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';

/// Compact device-health card driven by `/events/telemetry/latest/`.
/// Optional sparkline uses [history] (oldest → newest battery %).
class DeviceHealthCard extends StatelessWidget {
  const DeviceHealthCard({
    super.key,
    required this.telemetry,
    this.history = const [],
  });

  final TelemetrySnapshot? telemetry;
  final List<TelemetrySnapshot> history;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final t = telemetry;

    if (t == null) {
      return AppCard(
        elevated: false,
        color: tokens.surfaceContainerLow,
        child: Text(
          'Device health will appear once telemetry syncs.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: tokens.secondaryText,
          ),
        ),
      );
    }

    final batteryColor = t.isLowBattery
        ? AppColors.danger
        : (t.charging ? AppColors.success : theme.colorScheme.primary);
    final spark = history
        .map((h) => (h.batteryPct ?? 0).toDouble())
        .where((v) => v > 0)
        .toList();

    return Semantics(
      label:
          'Device health. Battery ${t.batteryPct ?? "unknown"} percent'
          '${t.charging ? ", charging" : ""}. '
          'Network ${t.networkType.isEmpty ? "unknown" : t.networkType}. '
          '${t.storageLabel == null ? "" : "Storage ${t.storageLabel}."}',
      child: AppCard(
        color: t.isLowBattery ? tokens.dangerSoft : tokens.primarySoft,
        elevated: false,
        borderColor: t.isLowBattery
            ? AppColors.danger.withValues(alpha: 0.35)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  t.charging
                      ? Icons.battery_charging_full_rounded
                      : (t.isLowBattery
                          ? Icons.battery_alert_rounded
                          : Icons.battery_std_rounded),
                  color: batteryColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  t.batteryPct == null ? '—%' : '${t.batteryPct}%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: batteryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (t.charging)
                  const StatusBadge(
                    label: 'Charging',
                    tone: StatusTone.success,
                    showDot: false,
                  )
                else if (t.isLowBattery)
                  const StatusBadge(
                    label: 'Low',
                    tone: StatusTone.danger,
                    showDot: false,
                  ),
                const Spacer(),
                if (t.updatedAt != null || t.capturedAt != null)
                  TimestampLabel(t.updatedAt ?? t.capturedAt!),
              ],
            ),
            if (spark.length >= 2) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 36,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    values: spark,
                    color: batteryColor,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _MetricChip(
                  icon: Icons.wifi_rounded,
                  label: t.networkType.isEmpty ? 'Network —' : t.networkType,
                ),
                if (t.storageLabel != null)
                  _MetricChip(
                    icon: Icons.sd_storage_outlined,
                    label: 'Storage ${t.storageLabel}',
                  ),
                if (t.ramLabel != null)
                  _MetricChip(
                    icon: Icons.memory_rounded,
                    label: 'RAM ${t.ramLabel}',
                  ),
              ],
            ),
            if (t.storageUsedFraction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: t.storageUsedFraction,
                  minHeight: 6,
                  backgroundColor: tokens.input,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tokens.secondaryText),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: tokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - ((values[i] - minV) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/consent/models/consent_scope.dart';
import 'package:spy_love/features/devices/controllers/device_detail_controller.dart';
import 'package:spy_love/features/devices/models/app_usage_model.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/section_header.dart';

/// Device-detail "Usage" tab — consented screen-time / app-usage feed.
class UsageTab extends StatelessWidget {
  const UsageTab({super.key});

  bool _hasUsageConsent(DeviceDetailController controller) {
    final scopes = (controller.consent?['scopes'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toSet();
    return scopes.contains('app_usage');
  }

  Future<void> _pickCustom(BuildContext context) async {
    final controller = context.read<DeviceDetailController>();
    final now = DateTime.now();
    final from = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      initialDate: controller.usageCustomFrom ??
          now.subtract(const Duration(days: 7)),
      helpText: 'From',
    );
    if (from == null || !context.mounted) return;
    final to = await showDatePicker(
      context: context,
      firstDate: from,
      lastDate: now,
      initialDate: controller.usageCustomTo ?? now,
      helpText: 'To',
    );
    if (to == null || !context.mounted) return;
    await controller.setUsageCustomRange(
      from,
      DateTime(to.year, to.month, to.day, 23, 59, 59),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceDetailController>();
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final consented = _hasUsageConsent(controller);
    final snap = controller.usageSnapshot;
    final maxMs = snap == null || snap.results.isEmpty
        ? 1
        : snap.results.first.foregroundMs.clamp(1, 1 << 31);

    if (!consented) {
      return const EmptyState(
        icon: Icons.hourglass_disabled_outlined,
        title: 'App usage not consented',
        message:
            'The device owner has not granted the App usage consent scope. '
            'Re-pair with that scope to view screen time.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.refreshUsage(),
      child: ListView(
        padding: context.pagePadding,
        children: [
          SectionHeader(
            title: 'Screen time',
            subtitle: snap == null
                ? 'Foreground time across consented apps'
                : '${snap.appCount} apps · ${formatForeground(Duration(milliseconds: snap.totalForegroundMs))} total',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final range in UsageRange.values)
                ChoiceChip(
                  label: Text(range.label),
                  selected: controller.usageRange == range,
                  onSelected: (_) {
                    if (range == UsageRange.custom) {
                      _pickCustom(context);
                    } else {
                      controller.setUsageRange(range);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (controller.isLoadingUsage && snap == null)
            const LoadingSkeleton(lines: 4)
          else if (controller.usageError.isNotEmpty && snap == null)
            ErrorState(
              message: controller.usageError,
              onRetry: () => controller.refreshUsage(),
            )
          else if (snap == null || snap.results.isEmpty)
            const EmptyState(
              icon: Icons.apps_outage_outlined,
              title: 'No usage yet',
              message:
                  'Usage syncs from the monitored device once App usage '
                  'consent is active and the device has reported.',
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < snap.results.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: tokens.border),
                    _UsageRow(
                      entry: snap.results[i],
                      fraction: snap.results[i].foregroundMs / maxMs,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sorted by foreground time. Launch counts come from the '
            '${ConsentScope.all.firstWhere((s) => s.id == 'app_usage').label} '
            'consent feed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.entry, required this.fraction});

  final AppUsageEntry entry;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Semantics(
      label:
          '${entry.displayName}, ${formatForeground(entry.foreground)}, '
          '${entry.launches} launches',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: tokens.primarySoft,
                  child: Text(
                    entry.displayName.isEmpty
                        ? '?'
                        : entry.displayName[0].toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        entry.package,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatForeground(entry.foreground),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${entry.launches} launch${entry.launches == 1 ? '' : 'es'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: tokens.input,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

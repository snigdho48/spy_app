import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';
import 'package:spy_love/features/devices/controllers/activity_timeline_controller.dart';
import 'package:spy_love/features/devices/models/activity_item.dart';

/// Unified reverse-chronological activity timeline for one device.
class ActivityTimelineView extends StatefulWidget {
  const ActivityTimelineView({super.key});

  @override
  State<ActivityTimelineView> createState() => _ActivityTimelineViewState();
}

class _ActivityTimelineViewState extends State<ActivityTimelineView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ActivityTimelineController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ActivityTimelineController>();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Activity timeline'),
            Text(
              controller.device.name,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      body: _buildBody(context, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ActivityTimelineController controller,
  ) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.accessDenied) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: EmptyState(
          icon: Icons.lock_outline,
          title: 'Timeline unavailable',
          message:
              'This device is shared with you as a viewer, or the owner has '
              'paused sharing. You do not have permission to see its activity.',
        ),
      );
    }
    if (controller.hasError) {
      return ErrorState(
        message: controller.error ?? 'Could not load activity',
        onRetry: controller.load,
      );
    }

    final filters = _FilterBar(controller: controller);
    if (controller.isEmpty) {
      return Column(
        children: [
          filters,
          const Expanded(
            child: EmptyState(
              icon: Icons.timeline_outlined,
              title: 'Nothing here yet',
              message:
                  'Consented activity for this device will appear here as it '
                  'arrives.',
            ),
          ),
        ],
      );
    }

    final days = controller.grouped;
    return Column(
      children: [
        filters,
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 320 &&
                  controller.hasMore &&
                  !controller.loadingMore) {
                controller.loadMore();
              }
              return false;
            },
            child: AppPage(
              onRefresh: controller.refresh,
              children: [
                for (final day in days) ...[
                  _DayHeader(day: day.day),
                  for (final item in day.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ActivityTile(item: item),
                    ),
                ],
                if (controller.loadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final ActivityTimelineController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.activeFilters;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: const Text('All'),
              selected: active.isEmpty,
              onSelected: (_) => controller.clearFilters(),
            ),
          ),
          for (final category in ActivityCategory.filterable)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                avatar: Icon(category.icon, size: 16),
                label: Text(category.label),
                selected: active.contains(category),
                onSelected: (_) => controller.toggleFilter(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        _label(day),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }

  String _label(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${day.year}-${_two(day.month)}-${_two(day.day)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final headline = _headline();
    final sub = _subtitle();

    return Semantics(
      label:
          '${item.category.label}. $headline. '
          '${item.timestamp.toLocal()}',
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.category.icon,
              size: 22,
              color: item.isCritical ? tokens.revoked : theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          headline,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.isAlert)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (item.isCritical
                                        ? tokens.revoked
                                        : theme.colorScheme.primary)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.severity?.toUpperCase() ?? 'ALERT',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sub, style: theme.textTheme.bodySmall),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  TimestampLabel(item.timestamp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _headline() {
    if (item.title.isNotEmpty) return item.title;
    final type = item.eventType.isEmpty ? item.category.label : item.eventType;
    return _humanize(type);
  }

  String _subtitle() {
    if (item.body.isNotEmpty) return item.body;
    return '';
  }

  String _humanize(String raw) {
    final cleaned = raw.replaceAll('.', ' · ').replaceAll('_', ' ');
    if (cleaned.isEmpty) return cleaned;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

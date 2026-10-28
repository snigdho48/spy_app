import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/alerts/controllers/alerts_controller.dart';
import 'package:spy_love/features/alerts/models/alert_model.dart';
import 'package:spy_love/features/alerts/views/alert_tile.dart';
import 'package:spy_love/features/alerts/views/alert_detail_sheet.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/section_header.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';

/// Alerts center. Used as a top-level dashboard tab and, scoped to a device,
/// as the per-device Alerts tab.
class AlertsView extends StatefulWidget {
  const AlertsView({super.key, this.deviceId, this.showHeader = true});

  /// When set, the list is scoped to a single device.
  final String? deviceId;
  final bool showHeader;

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<AlertsController>();
      controller.setDeviceScope(widget.deviceId);
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 240) {
      context.read<AlertsController>().loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openDetail(AlertModel alert) async {
    final controller = context.read<AlertsController>();
    await controller.markRead(alert.id);
    if (!mounted) return;
    await showAlertDetailSheet(context, alert);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final controller = context.watch<AlertsController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SectionHeader(
              title: 'Alerts',
              subtitle: controller.unreadCount > 0
                  ? '${controller.unreadCount} unread'
                  : 'All caught up',
              action: controller.unreadCount > 0
                  ? TextButton.icon(
                      onPressed: controller.markAllRead,
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Mark all read'),
                    )
                  : null,
            ),
          ),
        _FilterBar(controller: controller),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => controller.refresh(),
            child: _buildBody(context, controller, tokens),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AlertsController controller,
    AppTokens tokens,
  ) {
    if (controller.isLoading && controller.alerts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LoadingSkeleton(lines: 5),
      );
    }
    if (controller.errorMessage.isNotEmpty && controller.alerts.isEmpty) {
      return ListView(
        children: [
          ErrorState(
            message: controller.errorMessage,
            onRetry: () => controller.refresh(),
          ),
        ],
      );
    }
    if (controller.alerts.isEmpty) {
      return ListView(
        children: const [
          EmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'No alerts',
            message:
                'Geofence, SIM, battery and SOS alerts for consented devices '
                'will appear here.',
          ),
        ],
      );
    }

    final grouped = _groupByDay(controller.alerts);

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: grouped.length + (controller.hasNext ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= grouped.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final entry = grouped[index];
        if (entry.alert == null) {
          return Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              entry.heading!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
          );
        }
        final alert = entry.alert!;
        final tile = AlertTile(
          alert: alert,
          onTap: () => _openDetail(alert),
        );
        if (!controller.canDelete) return tile;
        return Dismissible(
          key: ValueKey('alert-${alert.id}'),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(tokens),
          confirmDismiss: (_) async {
            final ok = await controller.delete(alert.id);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You do not have permission to delete alerts'),
                ),
              );
            }
            return ok;
          },
          child: tile,
        );
      },
    );
  }

  Widget _deleteBackground(AppTokens tokens) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.dangerSoft,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Icon(Icons.delete_outline, color: tokens.revokeText),
    );
  }

  List<_GroupEntry> _groupByDay(List<AlertModel> alerts) {
    final entries = <_GroupEntry>[];
    String? lastHeading;
    for (final alert in alerts) {
      final heading = _dayHeading(alert.createdAt);
      if (heading != lastHeading) {
        entries.add(_GroupEntry.heading(heading));
        lastHeading = heading;
      }
      entries.add(_GroupEntry.alert(alert));
    }
    return entries;
  }

  String _dayHeading(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return TimestampLabel.format(timestamp, compact: false).split(' ').first;
  }
}

class _GroupEntry {
  const _GroupEntry.heading(this.heading) : alert = null;
  const _GroupEntry.alert(this.alert) : heading = null;

  final String? heading;
  final AlertModel? alert;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final AlertsController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          FilterChip(
            label: const Text('Unread'),
            selected: controller.unreadOnly,
            onSelected: (_) => controller.toggleUnreadOnly(),
          ),
          const SizedBox(width: AppSpacing.sm),
          ChoiceChip(
            label: const Text('All types'),
            selected: controller.typeFilter == null,
            onSelected: (_) => controller.setTypeFilter(null),
          ),
          for (final type in AlertType.filterable) ...[
            const SizedBox(width: AppSpacing.sm),
            ChoiceChip(
              label: Text(type.label),
              selected: controller.typeFilter == type,
              onSelected: (_) => controller.setTypeFilter(type),
            ),
          ],
        ],
      ),
    );
  }
}

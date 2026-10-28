import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';

/// Monitor-side notifications feed, distinct from chat. Reads
/// `notification.posted` / `notification.removed` / `notification.snapshot`
/// events (GET /events/?event_prefix=notification). Consent scope:
/// `notifications`.
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({
    super.key,
    required this.events,
    required this.isLoading,
  });

  final List<DeviceEventModel> events;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    if (isLoading && events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LoadingSkeleton(lines: 5),
      );
    }

    if (events.isEmpty) {
      return const EmptyState(
        title: 'No notifications yet',
        message:
            'General app notifications (not chat) appear here. The device needs '
            'notification access granted and the notifications scope consented.',
      );
    }

    return ListView.separated(
      padding: context.pagePadding,
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final e = events[i];
        final p = e.payload;
        final removed = e.eventType == 'notification.removed';
        final app = (p['app'] ?? p['package'] ?? '').toString();
        final title = (p['title'] ?? app).toString();
        final text = (p['text'] ?? p['body'] ?? '').toString();
        final category = (p['category'] ?? '').toString();
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: removed ? tokens.dangerSoft : tokens.primarySoft,
            child: Icon(
              removed
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined,
              color: removed ? tokens.revokeText : theme.colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(title.isEmpty ? app : title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (text.isNotEmpty)
                Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              Text(
                [
                  app,
                  if (category.isNotEmpty) category,
                  if (removed) 'dismissed',
                ].join(' · '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
            ],
          ),
          trailing: TimestampLabel(e.eventTimestamp),
          isThreeLine: text.isNotEmpty,
        );
      },
    );
  }
}

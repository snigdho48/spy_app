import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';

class EventDetailView extends StatelessWidget {
  const EventDetailView({super.key, this.args = const <String, dynamic>{}});

  final Map<String, dynamic> args;

  @override
  Widget build(BuildContext context) {
    final event = args['event'] as DeviceEventModel?;
    final deviceName = args['deviceName'] as String? ?? 'Device';
    final consentActive = args['consentActive'] as bool? ?? true;

    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event details')),
        body: const Center(child: Text('Event not found')),
      );
    }

    final tokens = context.tokens;
    final meta = EventPresentation.from(event);
    final payloadLines = event.payload.entries
        .where((e) => e.value != null && '${e.value}'.trim().isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(meta.sourceLabel)),
      body: AppPage(
        children: [
          Text(
            'Event details',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Captured on $deviceName • ${TimestampLabel.format(event.eventTimestamp, compact: false)}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meta.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusBadge.consent(active: consentActive),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TimestampLabel(event.eventTimestamp, compact: false),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Captured event',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  meta.fullBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (meta.disclaimer != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    meta.disclaimer!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event metadata',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MetaRow(label: 'Source', value: meta.sourceLabel),
                _MetaRow(label: 'Device', value: deviceName),
                _MetaRow(
                  label: 'Consent',
                  value: consentActive ? 'Consented' : 'Not granted',
                ),
                _MetaRow(label: 'Type', value: event.eventType),
                _MetaRow(
                  label: 'Captured',
                  value: TimestampLabel.format(
                    event.eventTimestamp,
                    compact: false,
                  ),
                ),
              ],
            ),
          ),
          if (payloadLines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payload',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...payloadLines.map(
                    (entry) =>
                        _MetaRow(label: entry.key, value: '${entry.value}'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.tokens.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Shared presentation helpers for event list + detail.
class EventPresentation {
  EventPresentation._({
    required this.title,
    required this.preview,
    required this.fullBody,
    required this.sourceLabel,
    required this.icon,
    required this.disclaimer,
  });

  final String title;
  final String preview;
  final String fullBody;
  final String sourceLabel;
  final IconData icon;
  final String? disclaimer;

  factory EventPresentation.from(DeviceEventModel event) {
    final type = event.eventType.toLowerCase();
    final payload = event.payload;

    if (type.contains('call')) {
      final contact = event.contact;
      final number =
          payload['number']?.toString() ??
          payload['phone']?.toString() ??
          'Unknown';
      final direction = payload['direction']?.toString() ?? 'call';
      final title = contact.contactName ?? number;
      return EventPresentation._(
        title: title,
        preview: direction,
        fullBody: '$direction · $number',
        sourceLabel: 'Calls',
        icon: Icons.call_outlined,
        disclaimer: null,
      );
    }
    if (type.contains('sms')) {
      final contact = event.contact;
      final redacted = contact.isRedacted;
      final body = redacted
          ? 'Content redacted'
          : (payload['body']?.toString() ??
              payload['preview']?.toString() ??
              'Message');
      final address =
          contact.contactName ??
          payload['address']?.toString() ??
          payload['sender']?.toString() ??
          'Unknown';
      return EventPresentation._(
        title: address,
        preview: body,
        fullBody: body,
        sourceLabel: 'SMS',
        icon: Icons.sms_outlined,
        disclaimer: redacted ? 'Message body was redacted on the device.' : null,
      );
    }
    if (type.contains('message') || type.contains('notification')) {
      final body =
          payload['body']?.toString() ??
          payload['preview']?.toString() ??
          'Notification';
      final title =
          payload['title']?.toString() ??
          payload['app']?.toString() ??
          'Chat alert';
      return EventPresentation._(
        title: title,
        preview: body,
        fullBody: body,
        sourceLabel: 'Messages',
        icon: Icons.chat_bubble_outline,
        disclaimer:
            'Captured from notification access with consent — not a full message archive.',
      );
    }
    if (type.contains('location')) {
      final lat = payload['lat'] ?? payload['latitude'];
      final lng = payload['lng'] ?? payload['longitude'];
      final label = (lat != null && lng != null)
          ? '$lat, $lng'
          : 'Location update';
      return EventPresentation._(
        title: 'Location',
        preview: label,
        fullBody: label,
        sourceLabel: 'Location',
        icon: Icons.location_on_outlined,
        disclaimer: null,
      );
    }
    if (type.contains('sim')) {
      final label =
          payload['phone_number']?.toString() ??
          payload['status']?.toString() ??
          'SIM update';
      return EventPresentation._(
        title: 'SIM security',
        preview: label,
        fullBody: label,
        sourceLabel: 'SIM',
        icon: Icons.sim_card_outlined,
        disclaimer: null,
      );
    }

    final title = payload['title']?.toString() ?? event.eventType;
    final preview =
        payload['body']?.toString() ??
        payload['message']?.toString() ??
        event.eventType;
    return EventPresentation._(
      title: title,
      preview: preview,
      fullBody: preview,
      sourceLabel: 'Event',
      icon: Icons.notifications_outlined,
      disclaimer: null,
    );
  }
}

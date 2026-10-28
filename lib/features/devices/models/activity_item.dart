import 'package:flutter/material.dart';

/// A category of activity shown in the unified timeline. Maps to the backend
/// `/events/activity/` `types` filter values and to event_type prefixes used by
/// the client-side fallback merge.
enum ActivityCategory {
  location('location', 'Location', Icons.location_on_outlined),
  appInventory('app_inventory', 'Apps', Icons.apps_outlined),
  notifications('notifications', 'Notifications', Icons.notifications_outlined),
  appUsage('app_usage', 'Usage', Icons.timelapse_outlined),
  telemetry('telemetry', 'Device health', Icons.favorite_outline),
  contacts('contacts', 'Contacts', Icons.contacts_outlined),
  calls('calls', 'Calls', Icons.call_outlined),
  sms('sms', 'SMS', Icons.sms_outlined),
  messages('messages', 'Messages', Icons.chat_bubble_outline),
  alerts('alerts', 'Alerts', Icons.warning_amber_outlined),
  other('other', 'Other', Icons.circle_outlined);

  const ActivityCategory(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;

  static ActivityCategory fromId(String? raw) {
    final value = (raw ?? '').toLowerCase();
    for (final c in ActivityCategory.values) {
      if (c.id == value) return c;
    }
    return ActivityCategory.other;
  }

  /// Match an event_type to a category (client-side fallback merge).
  static ActivityCategory fromEventType(String eventType) {
    final t = eventType.toLowerCase();
    if (t.startsWith('location.') || t.startsWith('geofence.')) {
      return ActivityCategory.location;
    }
    if (t.startsWith('app_inventory.')) return ActivityCategory.appInventory;
    if (t.startsWith('notification.')) return ActivityCategory.notifications;
    if (t.startsWith('app_usage.')) return ActivityCategory.appUsage;
    if (t.startsWith('device.')) return ActivityCategory.telemetry;
    if (t.startsWith('contact.')) return ActivityCategory.contacts;
    if (t.startsWith('call.')) return ActivityCategory.calls;
    if (t.startsWith('sms.')) return ActivityCategory.sms;
    if (t.startsWith('message.')) return ActivityCategory.messages;
    return ActivityCategory.other;
  }

  /// Categories the user can filter by in the timeline.
  static List<ActivityCategory> get filterable =>
      ActivityCategory.values.where((c) => c != ActivityCategory.other).toList();
}

/// One entry in the unified activity timeline — an event or an alert.
@immutable
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.source,
    required this.category,
    required this.eventType,
    required this.timestamp,
    required this.payload,
    this.title = '',
    this.body = '',
    this.severity,
  });

  final String id;

  /// `event` or `alert`.
  final String source;
  final ActivityCategory category;
  final String eventType;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final String title;
  final String body;
  final String? severity;

  bool get isAlert => source == 'alert';

  bool get isCritical => (severity ?? '').toLowerCase() == 'critical';

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'].toString(),
      source: json['source']?.toString() ?? 'event',
      category: ActivityCategory.fromId(json['category'] as String?),
      eventType: json['event_type']?.toString() ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      severity: json['severity']?.toString(),
    );
  }
}

/// One page of the activity feed plus the cursor for the next page.
class ActivityPage {
  const ActivityPage({required this.items, this.nextCursor});

  final List<ActivityItem> items;
  final String? nextCursor;

  bool get hasNext => nextCursor != null && nextCursor!.isNotEmpty;
}

/// Outcome of a single activity-feed fetch, distinguishing an access denial
/// (403 — VIEWER or consent off) and an unavailable endpoint (404 — backend not
/// yet deployed, caller should fall back to a client-side merge) from a loaded
/// page or a generic error.
class ActivityFetchOutcome {
  const ActivityFetchOutcome._({
    this.page,
    this.error,
    this.accessDenied = false,
    this.unavailable = false,
  });

  factory ActivityFetchOutcome.loaded(ActivityPage page) =>
      ActivityFetchOutcome._(page: page);
  factory ActivityFetchOutcome.denied() =>
      const ActivityFetchOutcome._(accessDenied: true);
  factory ActivityFetchOutcome.notAvailable() =>
      const ActivityFetchOutcome._(unavailable: true);
  factory ActivityFetchOutcome.failed(String message) =>
      ActivityFetchOutcome._(error: message);

  final ActivityPage? page;
  final String? error;
  final bool accessDenied;
  final bool unavailable;
}

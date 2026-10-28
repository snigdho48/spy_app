import 'package:flutter/material.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';

/// Severity levels emitted by the backend alerts feed.
enum AlertSeverity {
  info,
  warning,
  high,
  critical;

  static AlertSeverity fromJson(String? raw) {
    return switch ((raw ?? '').toLowerCase()) {
      'warning' => AlertSeverity.warning,
      'high' => AlertSeverity.high,
      'critical' => AlertSeverity.critical,
      _ => AlertSeverity.info,
    };
  }

  StatusTone get tone => switch (this) {
    AlertSeverity.info => StatusTone.info,
    AlertSeverity.warning => StatusTone.warning,
    AlertSeverity.high => StatusTone.danger,
    AlertSeverity.critical => StatusTone.danger,
  };

  String get label => switch (this) {
    AlertSeverity.info => 'Info',
    AlertSeverity.warning => 'Warning',
    AlertSeverity.high => 'High',
    AlertSeverity.critical => 'Critical',
  };
}

/// Known alert types. [other] keeps forward compatibility with new server types.
enum AlertType {
  geofenceEnter('geofence_enter', 'Entered safe zone', Icons.login_rounded),
  geofenceExit('geofence_exit', 'Left safe zone', Icons.logout_rounded),
  appInstalled('app_installed', 'App installed', Icons.download_rounded),
  simChanged('sim_changed', 'SIM changed', Icons.sim_card_rounded),
  lowBattery('low_battery', 'Low battery', Icons.battery_alert_rounded),
  sos('sos', 'SOS', Icons.sos_rounded),
  other('', 'Alert', Icons.notifications_active_outlined);

  const AlertType(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;

  static AlertType fromId(String? raw) {
    final value = (raw ?? '').toLowerCase();
    for (final t in AlertType.values) {
      if (t != AlertType.other && t.id == value) return t;
    }
    return AlertType.other;
  }

  /// Types the user can filter by in the Alerts center.
  static List<AlertType> get filterable =>
      AlertType.values.where((t) => t != AlertType.other).toList();
}

@immutable
class AlertModel {
  const AlertModel({
    required this.id,
    required this.type,
    required this.rawType,
    required this.severity,
    required this.title,
    required this.body,
    required this.metadata,
    required this.createdAt,
    required this.isRead,
    this.deviceId,
    this.readAt,
  });

  final String id;
  final AlertType type;
  final String rawType;
  final AlertSeverity severity;
  final String title;
  final String body;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool isRead;
  final String? deviceId;
  final DateTime? readAt;

  String get typeLabel =>
      type == AlertType.other && rawType.isNotEmpty ? rawType : type.label;

  AlertModel copyWith({bool? isRead, DateTime? readAt}) {
    return AlertModel(
      id: id,
      type: type,
      rawType: rawType,
      severity: severity,
      title: title,
      body: body,
      metadata: metadata,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      deviceId: deviceId,
      readAt: readAt ?? this.readAt,
    );
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    return AlertModel(
      id: json['id'].toString(),
      type: AlertType.fromId(json['type'] as String?),
      rawType: json['type']?.toString() ?? '',
      severity: AlertSeverity.fromJson(json['severity'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: created,
      isRead: json['is_read'] as bool? ?? json['read_at'] != null,
      deviceId: json['device_id']?.toString(),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
    );
  }
}

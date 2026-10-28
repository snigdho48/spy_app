import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/features/alerts/models/alert_model.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';

void main() {
  test('alert types map from backend ids and fall back to other', () {
    expect(AlertType.fromId('geofence_enter'), AlertType.geofenceEnter);
    expect(AlertType.fromId('low_battery'), AlertType.lowBattery);
    expect(AlertType.fromId('sos'), AlertType.sos);
    expect(AlertType.fromId('something_new'), AlertType.other);
    expect(AlertType.filterable.contains(AlertType.other), isFalse);
  });

  test('severity maps to tone and defaults to info', () {
    expect(AlertSeverity.fromJson('critical'), AlertSeverity.critical);
    expect(AlertSeverity.fromJson('warning').tone, StatusTone.warning);
    expect(AlertSeverity.fromJson(null), AlertSeverity.info);
    expect(AlertSeverity.fromJson('high').tone, StatusTone.danger);
  });

  test('fromJson parses the documented alert shape', () {
    final alert = AlertModel.fromJson({
      'id': 42,
      'device_id': 'dev-1',
      'type': 'geofence_exit',
      'severity': 'high',
      'title': 'Left School',
      'body': 'Device left the School safe zone',
      'metadata': {'zone': 'School'},
      'created_at': '2026-10-28T06:00:00Z',
      'read_at': null,
      'is_read': false,
    });

    expect(alert.id, '42');
    expect(alert.deviceId, 'dev-1');
    expect(alert.type, AlertType.geofenceExit);
    expect(alert.severity, AlertSeverity.high);
    expect(alert.isRead, isFalse);
    expect(alert.metadata['zone'], 'School');
  });

  test('copyWith marks an alert read', () {
    final alert = AlertModel.fromJson({
      'id': '1',
      'type': 'sos',
      'severity': 'critical',
      'title': 'SOS',
      'created_at': '2026-10-28T06:00:00Z',
      'is_read': false,
    });
    final read = alert.copyWith(isRead: true, readAt: DateTime(2026, 10, 28));
    expect(read.isRead, isTrue);
    expect(read.readAt, DateTime(2026, 10, 28));
    expect(alert.isRead, isFalse);
  });
}

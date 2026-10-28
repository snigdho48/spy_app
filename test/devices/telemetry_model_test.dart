import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/features/devices/models/telemetry_model.dart';

void main() {
  test('parses telemetry latest and flags low battery', () {
    final snap = TelemetrySnapshot.fromJson({
      'device_id': 'd1',
      'battery_pct': 12,
      'charging': false,
      'network_type': 'wifi',
      'storage_free': 5 * (1 << 30),
      'storage_total': 64 * (1 << 30),
      'ram_free': 2 * (1 << 30),
      'ram_total': 8 * (1 << 30),
      'metrics': {},
      'captured_at': '2026-10-28T06:00:00Z',
    });
    expect(snap.isLowBattery, isTrue);
    expect(snap.storageUsedFraction, closeTo(59 / 64, 0.01));
    expect(snap.storageLabel, contains('GB'));
    expect(snap.networkType, 'wifi');
  });

  test('charging suppresses the low-battery cue', () {
    final snap = TelemetrySnapshot.fromJson({
      'device_id': 'd1',
      'battery_pct': 10,
      'charging': true,
      'network_type': 'lte',
    });
    expect(snap.isLowBattery, isFalse);
  });
}

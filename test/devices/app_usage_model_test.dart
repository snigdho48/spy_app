import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/features/devices/models/app_usage_model.dart';

void main() {
  test('snapshot sorts by foreground and formats durations', () {
    final snap = AppUsageSnapshot.fromJson({
      'device_id': 'd1',
      'from': '2026-10-28T00:00:00Z',
      'to': '2026-10-28T23:59:59Z',
      'app_count': 2,
      'results': [
        {
          'package': 'a.b',
          'app_name': 'Short',
          'foreground_ms': 45 * 1000,
          'launches': 3,
        },
        {
          'package': 'c.d',
          'app_name': 'Long',
          'foreground_ms': 2 * 60 * 60 * 1000 + 15 * 60 * 1000,
          'launches': 1,
        },
      ],
    });
    expect(snap.results.first.appName, 'Long');
    expect(formatForeground(snap.results.first.foreground), '2h 15m');
    expect(formatForeground(snap.results.last.foreground), '45s');
    expect(snap.totalForegroundMs, greaterThan(0));
  });
}

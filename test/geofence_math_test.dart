import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/app/core/monitoring/geofence_math.dart';

void main() {
  test('distanceMeters is ~0 for the same point', () {
    final d = distanceMeters(lat1: 23.81, lng1: 90.41, lat2: 23.81, lng2: 90.41);
    expect(d, lessThan(1));
  });

  test('distanceMeters roughly matches a short urban offset', () {
    // ~111m north at equator-scale; at 23° still on the order of 100m.
    final d = distanceMeters(
      lat1: 23.8100,
      lng1: 90.4100,
      lat2: 23.8110,
      lng2: 90.4100,
    );
    expect(d, greaterThan(90));
    expect(d, lessThan(130));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/features/devices/models/safe_zone_model.dart';

void main() {
  test('fromJson defaults enabled to true and parses fields', () {
    final zone = SafeZoneModel.fromJson({
      'id': 7,
      'name': 'School',
      'lat': 23.81,
      'lng': 90.41,
      'radius_m': 250,
      'address': 'Dhaka',
      'device_id': 'dev-1',
    });
    expect(zone.id, '7');
    expect(zone.enabled, isTrue);
    expect(zone.radiusM, 250);
    expect(zone.label, 'Safe Zone: School');
  });

  test('copyWith flips enabled', () {
    const zone = SafeZoneModel(
      id: '1',
      name: 'Home',
      lat: 1,
      lng: 2,
      radiusM: 100,
      enabled: true,
    );
    expect(zone.copyWith(enabled: false).enabled, isFalse);
  });
}

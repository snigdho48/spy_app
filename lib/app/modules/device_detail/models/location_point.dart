import 'package:spy_love/app/modules/device_detail/models/device_event_model.dart';

class LocationPoint {
  const LocationPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.accuracyM,
    this.speedMps,
    this.placeName,
    this.zoneName,
    this.address,
    this.zoneId,
  });

  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? accuracyM;
  final double? speedMps;
  final String? placeName;
  final String? zoneName;
  final String? address;
  final String? zoneId;

  /// Prefer place_name / zone_name / address; fall back to compact coords.
  String get displayLabel {
    for (final candidate in [placeName, zoneName, address]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  factory LocationPoint.fromEvent(DeviceEventModel event) {
    final p = event.payload;
    String? str(String key) {
      final v = p[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return LocationPoint(
      lat: (p['lat'] as num).toDouble(),
      lng: (p['lng'] as num).toDouble(),
      timestamp: event.eventTimestamp,
      accuracyM: (p['accuracy_m'] as num?)?.toDouble(),
      speedMps: (p['speed_mps'] as num?)?.toDouble(),
      placeName: str('place_name') ?? str('place') ?? str('label'),
      zoneName: str('zone_name'),
      address: str('address'),
      zoneId: str('zone_id'),
    );
  }
}

enum LocationDateFilter { today, week, month, all }

extension LocationDateFilterX on LocationDateFilter {
  String get label => switch (this) {
        LocationDateFilter.today => 'Today',
        LocationDateFilter.week => '7 days',
        LocationDateFilter.month => '30 days',
        LocationDateFilter.all => 'All',
      };

  DateTime? get since => switch (this) {
        LocationDateFilter.today => DateTime.now().subtract(const Duration(days: 1)),
        LocationDateFilter.week => DateTime.now().subtract(const Duration(days: 7)),
        LocationDateFilter.month => DateTime.now().subtract(const Duration(days: 30)),
        LocationDateFilter.all => null,
      };
}

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:spy_love/app/modules/device_detail/models/location_point.dart';

List<LatLng> toLatLngs(List<LocationPoint> points) {
  return points.map((p) => LatLng(p.lat, p.lng)).toList();
}

LatLngBounds? boundsForPoints(List<LocationPoint> points) {
  if (points.isEmpty) return null;

  var minLat = points.first.lat;
  var maxLat = points.first.lat;
  var minLng = points.first.lng;
  var maxLng = points.first.lng;

  for (final p in points) {
    if (p.lat < minLat) minLat = p.lat;
    if (p.lat > maxLat) maxLat = p.lat;
    if (p.lng < minLng) minLng = p.lng;
    if (p.lng > maxLng) maxLng = p.lng;
  }

  const pad = 0.002;
  return LatLngBounds(
    LatLng(minLat - pad, minLng - pad),
    LatLng(maxLat + pad, maxLng + pad),
  );
}

LatLng centerForPoints(List<LocationPoint> points) {
  if (points.isEmpty) return const LatLng(0, 0);
  final latest = points.first;
  return LatLng(latest.lat, latest.lng);
}

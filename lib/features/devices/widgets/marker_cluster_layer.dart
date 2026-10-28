import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A single point fed into [MarkerClusterLayer].
class ClusterPoint {
  const ClusterPoint({
    required this.location,
    required this.child,
    this.width = 40,
    this.height = 40,
    this.data,
  });

  final LatLng location;

  /// Rendered when the point is not clustered (a lone marker).
  final Widget child;
  final double width;
  final double height;

  /// Optional caller payload (e.g. a device id) for tap handling.
  final Object? data;
}

/// Lightweight, dependency-free marker clustering for flutter_map.
///
/// The published clustering plugins pin `latlong2 ^0.9.x`, which conflicts with
/// this app's `latlong2 ^0.10.1`, so clustering is implemented in-repo instead
/// of adding a plugin. This widget is a child of [FlutterMap]: it reads
/// [MapCamera.of] (an inherited model, so it rebuilds on every pan/zoom),
/// greedily groups points whose screen positions fall within [clusterRadiusPx],
/// and renders a [MarkerLayer] of either count bubbles or the original markers.
class MarkerClusterLayer extends StatelessWidget {
  const MarkerClusterLayer({
    super.key,
    required this.points,
    required this.mapController,
    this.clusterRadiusPx = 64,
    this.maxClusterZoom = 17,
    this.bubbleColor,
  });

  final List<ClusterPoint> points;
  final MapController mapController;
  final double clusterRadiusPx;

  /// Above this zoom everything is shown un-clustered.
  final double maxClusterZoom;
  final Color? bubbleColor;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final clusters = _cluster(camera);
    final color = bubbleColor ?? Theme.of(context).colorScheme.primary;

    return MarkerLayer(
      markers: [
        for (final c in clusters)
          if (c.members.length == 1)
            Marker(
              point: c.members.first.location,
              width: c.members.first.width,
              height: c.members.first.height,
              child: c.members.first.child,
            )
          else
            Marker(
              point: c.center,
              width: 46,
              height: 46,
              child: _ClusterBubble(
                count: c.members.length,
                color: color,
                onTap: () => _expand(camera, c),
              ),
            ),
      ],
    );
  }

  void _expand(MapCamera camera, _Cluster cluster) {
    final targetZoom = math.min(camera.zoom + 2, maxClusterZoom.toDouble());
    mapController.move(cluster.center, targetZoom);
  }

  List<_Cluster> _cluster(MapCamera camera) {
    if (camera.zoom >= maxClusterZoom || points.length < 2) {
      return [for (final p in points) _Cluster.single(p)];
    }

    final clusters = <_Cluster>[];
    final offsets = [for (final p in points) camera.latLngToScreenOffset(p.location)];
    final used = List<bool>.filled(points.length, false);
    final r2 = clusterRadiusPx * clusterRadiusPx;

    for (var i = 0; i < points.length; i++) {
      if (used[i]) continue;
      used[i] = true;
      final members = <ClusterPoint>[points[i]];
      for (var j = i + 1; j < points.length; j++) {
        if (used[j]) continue;
        final dx = offsets[i].dx - offsets[j].dx;
        final dy = offsets[i].dy - offsets[j].dy;
        if (dx * dx + dy * dy <= r2) {
          used[j] = true;
          members.add(points[j]);
        }
      }
      clusters.add(_Cluster(members));
    }
    return clusters;
  }
}

class _Cluster {
  _Cluster(this.members) : center = _centroid(members);
  _Cluster.single(ClusterPoint p) : members = [p], center = p.location;

  final List<ClusterPoint> members;
  final LatLng center;

  static LatLng _centroid(List<ClusterPoint> members) {
    var lat = 0.0;
    var lng = 0.0;
    for (final m in members) {
      lat += m.location.latitude;
      lng += m.location.longitude;
    }
    return LatLng(lat / members.length, lng / members.length);
  }
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({
    required this.count,
    required this.color,
    required this.onTap,
  });

  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$count locations clustered. Activate to zoom in.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

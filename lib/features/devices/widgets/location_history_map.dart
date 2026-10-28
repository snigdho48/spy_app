import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:spy_love/core/theme/app_colors.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/models/location_point.dart';
import 'package:spy_love/features/devices/utils/location_map_utils.dart';
import 'package:spy_love/shared/widgets/app_states.dart';

/// Shared flutter_map for location history (inline preview + full-screen).
class LocationHistoryMap extends StatelessWidget {
  const LocationHistoryMap({
    super.key,
    required this.points,
    this.mapController,
    this.interactive = true,
    this.showEmptyState = true,
    this.onTap,
  });

  final List<LocationPoint> points;
  final MapController? mapController;
  final bool interactive;
  final bool showEmptyState;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (points.isEmpty) {
      if (!showEmptyState) {
        return ColoredBox(color: tokens.input);
      }
      return ColoredBox(
        color: tokens.input,
        child: const EmptyState(
          icon: Icons.map_outlined,
          title: 'No location data yet',
          message:
              'Grant location on the monitored device to see live position and history.',
        ),
      );
    }

    final latest = points.first;
    final path = toLatLngs(points.reversed.toList());
    final primary = Theme.of(context).colorScheme.primary;

    final map = FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: centerForPoints(points),
        initialZoom: 14,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: onTap == null ? null : (_, _) => onTap!(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'org.hmg.spy_love',
        ),
        if (path.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: path,
                color: primary.withValues(alpha: 0.85),
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            ...points
                .skip(1)
                .map(
                  (p) => Marker(
                    point: LatLng(p.lat, p.lng),
                    width: 14,
                    height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),
            Marker(
              point: LatLng(latest.lat, latest.lng),
              width: 48,
              height: 48,
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.danger,
                size: 44,
              ),
            ),
          ],
        ),
      ],
    );

    if (onTap == null) return map;

    return Stack(
      fit: StackFit.expand,
      children: [
        map,
        // Capture taps on non-interactive preview without fighting map gestures.
        if (!interactive)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),
          ),
      ],
    );
  }
}

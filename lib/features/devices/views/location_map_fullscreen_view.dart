import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/models/location_point.dart';
import 'package:spy_love/features/devices/utils/location_map_utils.dart';
import 'package:spy_love/features/devices/widgets/location_history_map.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';

class LocationMapFullscreenArgs {
  const LocationMapFullscreenArgs({required this.points, this.deviceName});

  final List<LocationPoint> points;
  final String? deviceName;
}

class LocationMapFullscreenView extends StatefulWidget {
  const LocationMapFullscreenView({super.key, required this.args});

  final LocationMapFullscreenArgs args;

  @override
  State<LocationMapFullscreenView> createState() =>
      _LocationMapFullscreenViewState();
}

class _LocationMapFullscreenViewState extends State<LocationMapFullscreenView> {
  late final MapController _mapController = MapController();
  LocationPoint? _selected;

  @override
  void initState() {
    super.initState();
    final points = widget.args.points;
    _selected = points.isEmpty ? null : points.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fit() {
    final points = widget.args.points;
    if (points.isEmpty) return;
    final bounds = boundsForPoints(points);
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
      );
    } else {
      _mapController.move(LatLng(points.first.lat, points.first.lng), 15);
    }
  }

  void _focus(LocationPoint point) {
    setState(() => _selected = point);
    _mapController.move(LatLng(point.lat, point.lng), 16);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final points = widget.args.points;
    final title = widget.args.deviceName == null
        ? 'Location map'
        : '${widget.args.deviceName} · Map';

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.fit_screen_rounded),
              tooltip: 'Fit all points',
              onPressed: _fit,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LocationHistoryMap(
              points: points,
              mapController: _mapController,
              interactive: true,
            ),
          ),
          if (_selected != null)
            Material(
              color: tokens.surface,
              elevation: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tokens.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.place_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selected!.displayLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            TimestampLabel(
                              _selected!.timestamp,
                              compact: false,
                            ),
                            Text(
                              '${_selected!.lat.toStringAsFixed(5)}, '
                              '${_selected!.lng.toStringAsFixed(5)}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: tokens.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (points.length > 1)
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: points.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final point = points[index];
                  final selected =
                      identical(point, _selected) ||
                      (_selected != null &&
                          point.lat == _selected!.lat &&
                          point.lng == _selected!.lng &&
                          point.timestamp == _selected!.timestamp);
                  return ChoiceChip(
                    selected: selected,
                    label: Text(TimestampLabel.format(point.timestamp)),
                    onSelected: (_) => _focus(point),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/models/location_point.dart';
import 'package:spy_love/features/devices/utils/location_map_utils.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';

class LocationRoutePlaybackArgs {
  const LocationRoutePlaybackArgs({
    required this.points,
    this.deviceName,
  });

  /// Newest-first (same order as DeviceDetailController.filteredLocations).
  /// Playback reverses them into chronological order and caps at [maxPoints].
  final List<LocationPoint> points;
  final String? deviceName;

  /// Hard cap so a dense day stays animatable.
  static const int maxPoints = 500;
}

/// Scrubber that replays a device's location history as an animated polyline
/// + moving marker, with play/pause and speed controls.
class LocationRoutePlaybackView extends StatefulWidget {
  const LocationRoutePlaybackView({super.key, required this.args});

  final LocationRoutePlaybackArgs args;

  @override
  State<LocationRoutePlaybackView> createState() =>
      _LocationRoutePlaybackViewState();
}

class _LocationRoutePlaybackViewState extends State<LocationRoutePlaybackView> {
  final MapController _mapController = MapController();

  /// Chronological (oldest → newest), capped.
  late final List<LocationPoint> _path;

  int _index = 0;
  bool _playing = false;
  double _speed = 1;
  Timer? _timer;

  static const _speeds = [0.5, 1.0, 2.0, 4.0];
  static const _tickMs = 400;

  @override
  void initState() {
    super.initState();
    final reversed = widget.args.points.reversed.toList();
    _path = reversed.length > LocationRoutePlaybackArgs.maxPoints
        ? reversed.sublist(reversed.length - LocationRoutePlaybackArgs.maxPoints)
        : reversed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _fit() {
    if (_path.isEmpty) return;
    final bounds = boundsForPoints(_path);
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
      );
    } else {
      _mapController.move(LatLng(_path.first.lat, _path.first.lng), 15);
    }
  }

  void _togglePlay() {
    if (_playing) {
      _pause();
    } else {
      _play();
    }
  }

  void _play() {
    if (_path.length < 2) return;
    if (_index >= _path.length - 1) {
      setState(() => _index = 0);
    }
    setState(() => _playing = true);
    _scheduleTick();
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (_playing) setState(() => _playing = false);
  }

  void _scheduleTick() {
    _timer?.cancel();
    final ms = (_tickMs / _speed).round().clamp(40, 2000);
    _timer = Timer(Duration(milliseconds: ms), _tick);
  }

  void _tick() {
    if (!_playing || !mounted) return;
    if (_index >= _path.length - 1) {
      setState(() => _playing = false);
      return;
    }
    setState(() => _index += 1);
    final p = _path[_index];
    _mapController.move(LatLng(p.lat, p.lng), _mapController.camera.zoom);
    _scheduleTick();
  }

  void _scrub(double value) {
    final next = value.round().clamp(0, _path.length - 1);
    if (next == _index) return;
    setState(() => _index = next);
    final p = _path[_index];
    _mapController.move(LatLng(p.lat, p.lng), _mapController.camera.zoom);
  }

  void _cycleSpeed() {
    final i = _speeds.indexOf(_speed);
    final next = _speeds[(i + 1) % _speeds.length];
    setState(() => _speed = next);
    if (_playing) _scheduleTick();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = widget.args.deviceName == null
        ? 'Route playback'
        : '${widget.args.deviceName} · Playback';
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (_path.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const EmptyState(
          icon: Icons.route_outlined,
          title: 'No route to play',
          message: 'This device has no location points in the selected range.',
        ),
      );
    }

    final current = _path[_index];
    final trail = [for (var i = 0; i <= _index; i++) LatLng(_path[i].lat, _path[i].lng)];
    final remaining = [
      for (var i = _index; i < _path.length; i++) LatLng(_path[i].lat, _path[i].lng),
    ];

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
          IconButton(
            icon: const Icon(Icons.fit_screen_rounded),
            tooltip: 'Fit route',
            onPressed: _fit,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(current.lat, current.lng),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.hmg.spy_love',
                ),
                if (remaining.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: remaining,
                        color: primary.withValues(alpha: 0.25),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                if (trail.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: trail,
                        color: primary.withValues(alpha: 0.9),
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(current.lat, current.lng),
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.navigation_rounded,
                        color: tokens.revoked,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: tokens.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            current.displayLabel,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TimestampLabel(current.timestamp, compact: false),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_index + 1} / ${_path.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                    Semantics(
                      label: 'Route position scrubber',
                      child: Slider(
                        value: _index.toDouble(),
                        min: 0,
                        max: (_path.length - 1).toDouble(),
                        divisions: _path.length > 1 ? _path.length - 1 : null,
                        onChanged: _scrub,
                      ),
                    ),
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: _playing ? 'Pause playback' : 'Play route',
                          child: IconButton.filled(
                            onPressed: _path.length < 2 ? null : _togglePlay,
                            icon: Icon(
                              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: 'Playback speed ${_speed}x. Activate to cycle.',
                          child: OutlinedButton(
                            onPressed: _cycleSpeed,
                            child: Text('${_speed}x'),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _pause();
                            setState(() => _index = 0);
                            _fit();
                          },
                          child: const Text('Restart'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/routes.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/controllers/fleet_overview_controller.dart';
import 'package:spy_love/features/devices/models/device_overview.dart';
import 'package:spy_love/features/devices/utils/location_map_utils.dart';
import 'package:spy_love/features/devices/widgets/marker_cluster_layer.dart';
import 'package:spy_love/shared/widgets/app_states.dart';

/// Every accessible device's last-known location on one clustered map.
class AllDevicesMapView extends StatefulWidget {
  const AllDevicesMapView({super.key});

  @override
  State<AllDevicesMapView> createState() => _AllDevicesMapViewState();
}

class _AllDevicesMapViewState extends State<AllDevicesMapView> {
  final MapController _mapController = MapController();
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FleetOverviewController>().load();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<DeviceOverview> _located(FleetOverviewController c) =>
      c.overviews.where((o) => o.lastLocation != null).toList();

  void _fit(List<DeviceOverview> located) {
    if (_fitted || located.isEmpty) return;
    final pts = [for (final o in located) o.lastLocation!];
    final bounds = boundsForPoints(pts);
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(64)),
      );
      _fitted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FleetOverviewController>();
    final located = _located(controller);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit(located));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen_rounded),
            tooltip: 'Fit all devices',
            onPressed: () {
              _fitted = false;
              _fit(located);
            },
          ),
        ],
      ),
      body: _body(context, controller, located),
    );
  }

  Widget _body(
    BuildContext context,
    FleetOverviewController controller,
    List<DeviceOverview> located,
  ) {
    if (controller.isLoading && controller.overviews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.errorMessage.isNotEmpty && controller.overviews.isEmpty) {
      return ErrorState(
        message: controller.errorMessage,
        onRetry: controller.load,
      );
    }
    if (located.isEmpty) {
      return const EmptyState(
        icon: Icons.location_off_outlined,
        title: 'No device locations',
        message:
            'None of your accessible devices have shared a recent location yet.',
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: centerForPoints(
          [for (final o in located) o.lastLocation!],
        ),
        initialZoom: 11,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'org.hmg.spy_love',
        ),
        MarkerClusterLayer(
          mapController: _mapController,
          points: [
            for (final o in located)
              ClusterPoint(
                location: LatLng(o.lastLocation!.lat, o.lastLocation!.lng),
                width: 44,
                height: 52,
                data: o.device.id,
                child: _DevicePin(
                  overview: o,
                  onTap: () => AppNavigator.toNamed(
                    AppRoutes.deviceDetail,
                    arguments: o.device,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DevicePin extends StatelessWidget {
  const _DevicePin({required this.overview, required this.onTap});

  final DeviceOverview overview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = overview.criticalAlerts > 0
        ? tokens.revoked
        : overview.isOnline
        ? tokens.consented
        : tokens.secondaryText;
    return Semantics(
      button: true,
      label:
          '${overview.device.name}, '
          '${overview.isOnline ? 'online' : 'offline'}. Open device.',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: color, size: 36),
          ],
        ),
      ),
    );
  }
}


import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:spy_love/features/alerts/models/alert_model.dart';
import 'package:spy_love/features/alerts/repositories/alert_repository.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/models/device_overview.dart';
import 'package:spy_love/features/devices/models/location_point.dart';
import 'package:spy_love/features/devices/repositories/device_repository.dart';
import 'package:spy_love/features/devices/repositories/event_repository.dart';

/// Builds a multi-device "fleet" overview by fanning out over the existing
/// device list, telemetry, location and alerts feeds. Reuses the device
/// repository/controllers from Phase 1 and only adds summary wiring.
///
/// Foreground loads use the branded overlay via the device list call; every
/// per-device summary fetch and all background refreshes pass loader:false so
/// the global overlay never blocks the grid (matches the rest of the app).
class FleetOverviewController extends ChangeNotifier {
  FleetOverviewController(this._devices, this._events, this._alerts) {
    // ignore: discarded_futures
    load();
  }

  final DeviceRepository _devices;
  final EventRepository _events;
  final AlertRepository _alerts;

  List<DeviceOverview> overviews = <DeviceOverview>[];
  bool isLoading = false;
  bool _disposed = false;
  String errorMessage = '';

  FleetSummary get summary {
    var online = 0;
    var unread = 0;
    var critical = 0;
    for (final o in overviews) {
      if (o.isOnline) online += 1;
      unread += o.unreadAlerts;
      critical += o.criticalAlerts;
    }
    return FleetSummary(
      totalDevices: overviews.length,
      onlineDevices: online,
      totalUnreadAlerts: unread,
      criticalAlerts: critical,
    );
  }

  /// Foreground load (shows the branded overlay for the device list fetch).
  Future<void> load() => _load(silent: false);

  /// Pull-to-refresh / background refresh — never trips the global overlay.
  Future<void> refresh() => _load(silent: true);

  Future<void> _load({required bool silent}) async {
    if (!silent) {
      isLoading = true;
      errorMessage = '';
      _notify();
    }

    final result = await _devices.listDevices();
    if (_disposed) return;

    await result.fold((devices) async {
      errorMessage = '';
      // Seed cards immediately so the grid paints while summaries stream in.
      overviews = devices.map((d) => DeviceOverview(device: d)).toList();
      if (!silent) {
        isLoading = false;
      }
      _notify();
      await _loadSummaries(devices);
    }, (error) async {
      errorMessage = error;
      isLoading = false;
      _notify();
    });
  }

  Future<void> _loadSummaries(List<DeviceModel> devices) async {
    final next = <String, DeviceOverview>{
      for (final o in overviews) o.device.id: o,
    };

    await Future.wait(
      devices.map((device) async {
        final overview = await _fetchSummary(device);
        next[device.id] = overview;
      }),
    );

    if (_disposed) return;
    overviews = devices
        .map((d) => next[d.id] ?? DeviceOverview(device: d))
        .toList();
    _notify();
  }

  Future<DeviceOverview> _fetchSummary(DeviceModel device) async {
    int? battery;
    bool? charging;
    LocationPoint? lastLocation;
    var unread = 0;
    var critical = 0;
    var accessDenied = false;

    // Battery / charging from the latest telemetry snapshot.
    final telemetry = await _events.latestTelemetry(
      deviceId: device.id,
      loader: false,
    );
    if (telemetry != null) {
      battery = telemetry.batteryPct;
      charging = telemetry.charging;
    }

    // Last known location from the most recent location event.
    final location = await _events.listEvents(
      deviceId: device.id,
      eventPrefix: 'location',
      page: 1,
      pageSize: 1,
      loader: false,
    );
    location.fold((events) {
      final withCoords = events.where(
        (e) => e.payload['lat'] != null && e.payload['lng'] != null,
      );
      if (withCoords.isNotEmpty) {
        lastLocation = LocationPoint.fromEvent(withCoords.first);
      }
    }, (error) {
      if (error.toLowerCase().contains('permission') ||
          error.contains('403')) {
        accessDenied = true;
      }
    });

    // Unread + critical alert counts from a single small alert page.
    final alertPage = await _alerts.list(
      deviceId: device.id,
      unreadOnly: true,
      pageSize: 50,
      loader: false,
    );
    alertPage.fold((page) {
      unread = page.count;
      critical = page.alerts
          .where((a) => a.severity == AlertSeverity.critical)
          .length;
    }, (_) {});

    return DeviceOverview(
      device: device,
      batteryPercent: battery,
      batteryCharging: charging,
      lastLocation: lastLocation,
      unreadAlerts: unread,
      criticalAlerts: critical,
      accessDenied: accessDenied,
    );
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

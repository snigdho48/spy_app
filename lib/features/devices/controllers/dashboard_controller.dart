import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/permissions/permission_service.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/devices/models/device_home_snapshot.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/repositories/device_repository.dart';
import 'package:spy_love/features/devices/repositories/event_repository.dart';
import 'package:spy_love/features/devices/storage/device_list_cache.dart';
import 'package:spy_love/core/network/network_service.dart';

class DashboardController extends ChangeNotifier {
  DashboardController(
    this._repository,
    this._events,
    this._permissionService,
    this._auth,
    this._network,
  ) {
    _permissionService.addListener(notifyListeners);
    _auth.addListener(_onAuthChanged);
    _network.addListener(_onNetworkChanged);
    _permissionService.refreshStatuses();
    _onAuthChanged();
  }

  final DeviceRepository _repository;
  final EventRepository _events;
  final PermissionService _permissionService;
  final AuthController _auth;
  final NetworkService _network;
  bool _wasLoggedIn = false;
  bool _wasConnected = true;

  List<DeviceModel> devices = <DeviceModel>[];
  Map<String, DeviceHomeSnapshot> deviceSnapshots = {};
  bool isLoading = false;
  bool isRequestingPermissions = false;
  bool showingCachedData = false;
  DateTime? cacheSavedAt;
  String errorMessage = '';

  PermissionService get permissions => _permissionService;

  void _onAuthChanged() {
    final loggedIn = _auth.isLoggedIn;
    if (loggedIn == _wasLoggedIn) return;
    _wasLoggedIn = loggedIn;
    if (loggedIn) {
      loadDevices();
    } else {
      devices = <DeviceModel>[];
      deviceSnapshots = {};
      errorMessage = '';
      isLoading = false;
      showingCachedData = false;
      cacheSavedAt = null;
      notifyListeners();
      unawaited(DeviceListCache.clear());
    }
  }

  void _onNetworkChanged() {
    final online = _network.isConnected;
    if (online && !_wasConnected && _auth.isLoggedIn) {
      unawaited(loadDevices());
    }
    _wasConnected = online;
  }

  int get activeDeviceCount =>
      devices.where((d) => d.status.toLowerCase() == 'active').length;

  int get attentionCount {
    var count = devices.where((d) => d.status.toLowerCase() != 'active').length;
    if (!permissions.allGranted) count += 1;
    return count;
  }

  DeviceHomeSnapshot? snapshotFor(String deviceId) => deviceSnapshots[deviceId];

  Future<void> requestPermissions() async {
    isRequestingPermissions = true;
    notifyListeners();
    final granted = await _permissionService.requestMonitoringPermissions();
    isRequestingPermissions = false;
    notifyListeners();

    if (!granted) {
      AppNavigator.snackbar(
        'Permissions required',
        'Some permissions were denied. Monitoring features may not work until you grant them in Settings.',
        action: SnackBarAction(
          label: 'Settings',
          onPressed: _permissionService.openAppSettingsPage,
        ),
      );
    }
  }

  Future<void> loadDevices() async {
    if (!_auth.isLoggedIn) return;
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final result = await _repository.listDevices();
    if (result.isLeft) {
      devices = result.left;
      showingCachedData = false;
      errorMessage = '';
      isLoading = false;
      notifyListeners();
      await _loadHomeSnapshots();
      unawaited(
        DeviceListCache.save(devices: devices, snapshots: deviceSnapshots),
      );
      return;
    }

    errorMessage = result.right;
    final cached = await DeviceListCache.load();
    if (cached != null && cached.devices.isNotEmpty) {
      devices = cached.devices;
      deviceSnapshots = cached.snapshots;
      showingCachedData = true;
      cacheSavedAt = cached.savedAt;
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadHomeSnapshots() async {
    final targets = devices.take(4).toList();
    final next = Map<String, DeviceHomeSnapshot>.from(deviceSnapshots);

    await Future.wait(
      targets.map((device) async {
        final snap = await _fetchSnapshot(device.id);
        next[device.id] = snap;
      }),
    );

    deviceSnapshots = next;
    notifyListeners();
  }

  Future<DeviceHomeSnapshot> _fetchSnapshot(String deviceId) async {
    int? percent;
    bool? charging;
    String? place;
    DateTime? locationAt;

    final battery = await _events.listEvents(
      deviceId: deviceId,
      eventPrefix: 'battery',
      page: 1,
      pageSize: 1,
      loader: false,
    );
    battery.fold((events) {
      if (events.isEmpty) return;
      final p = events.first.payload;
      final level = p['level'] ?? p['percent'];
      if (level is num) percent = level.round();
      if (level is String) percent = int.tryParse(level);
      final c = p['charging'] ?? p['is_charging'];
      if (c is bool) charging = c;
      if (c != null) charging = c.toString().toLowerCase() == 'true';
    }, (_) {});

    final location = await _events.listEvents(
      deviceId: deviceId,
      eventPrefix: 'location',
      page: 1,
      pageSize: 1,
      loader: false,
    );
    location.fold((events) {
      if (events.isEmpty) return;
      final e = events.first;
      final p = e.payload;
      locationAt = e.eventTimestamp;
      final label =
          (p['place_name'] ??
                  p['zone_name'] ??
                  p['place'] ??
                  p['label'] ??
                  p['address'] ??
                  p['name'] ??
                  '')
              .toString()
              .trim();
      if (label.isNotEmpty) {
        place = label;
      } else if (p['lat'] != null && p['lng'] != null) {
        final lat = (p['lat'] as num).toDouble();
        final lng = (p['lng'] as num).toDouble();
        place =
            '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)} · ${TimestampLabel.relative(e.eventTimestamp)}';
      }
    }, (_) {});

    return DeviceHomeSnapshot(
      batteryPercent: percent,
      batteryCharging: charging,
      placeLabel: place,
      locationAt: locationAt,
    );
  }

  @override
  void dispose() {
    _network.removeListener(_onNetworkChanged);
    _auth.removeListener(_onAuthChanged);
    _permissionService.removeListener(notifyListeners);
    super.dispose();
  }
}

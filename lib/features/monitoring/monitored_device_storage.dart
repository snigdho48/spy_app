import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

/// Persists the monitored device id for background sync on the device-owner account.
///
/// [device_id] is the approved device only ([markLinked]). A pairing that has
/// been started but not yet approved is stored separately and must not start
/// [MonitoringService].
class MonitoredDeviceStorage {
  MonitoredDeviceStorage._();

  static const _boxName = 'monitored_device';
  static const _deviceIdKey = 'device_id';
  static const _pendingDeviceIdKey = 'pending_device_id';
  static const _linkedKey = 'linked';

  /// Bumped synchronously by [clear] so a write already in flight cannot put
  /// the previous account's device id back after logout.
  static int _generation = 0;
  static Future<void> _tail = Future<void>.value();

  static Future<T> _locked<T>(Future<T> Function() action) {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    return previous.then((_) => action()).whenComplete(gate.complete);
  }

  static Future<Box<dynamic>> _box() => Hive.openBox(_boxName);

  static Future<void> saveDeviceId(String deviceId) {
    final generation = _generation;
    return _locked(() async {
      if (generation != _generation) return;
      final box = await _box();
      if (generation != _generation) return;
      await box.put(_deviceIdKey, deviceId);
    });
  }

  static Future<String?> getDeviceId() async {
    final box = await _box();
    return box.get(_deviceIdKey) as String?;
  }

  static Future<void> savePendingDeviceId(String deviceId) {
    final generation = _generation;
    return _locked(() async {
      if (generation != _generation) return;
      final box = await _box();
      if (generation != _generation) return;
      await box.put(_pendingDeviceIdKey, deviceId);
    });
  }

  static Future<String?> getPendingDeviceId() async {
    final box = await _box();
    return box.get(_pendingDeviceIdKey) as String?;
  }

  static Future<bool> isMarkedLinked() async {
    final box = await _box();
    return box.get(_linkedKey) == true;
  }

  /// Records that the monitor approved this device, so collectors may run.
  static Future<void> markLinked(String deviceId) {
    final generation = _generation;
    return _locked(() async {
      if (generation != _generation) return;
      final box = await _box();
      if (generation != _generation) return;
      await box.put(_deviceIdKey, deviceId);
      await box.put(_linkedKey, true);
      await box.delete(_pendingDeviceIdKey);
    });
  }

  static Future<void> clear() {
    _generation++;
    final generation = _generation;
    return _locked(() async {
      if (generation != _generation) return;
      final box = await _box();
      await box.delete(_deviceIdKey);
      await box.delete(_pendingDeviceIdKey);
      await box.delete(_linkedKey);
    });
  }
}

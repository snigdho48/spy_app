import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:spy_love/core/storage/secure_hive.dart';
import 'package:spy_love/features/devices/models/device_home_snapshot.dart';
import 'package:spy_love/features/devices/models/device_model.dart';

/// Encrypted Hive cache of the last successful device list + home snapshots.
abstract final class DeviceListCache {
  static const boxName = 'device_cache';
  static const _devicesKey = 'devices_json';
  static const _snapshotsKey = 'snapshots_json';
  static const _savedAtKey = 'saved_at';

  static Future<void> ensureBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      await SecureHive.openBox(boxName);
    }
  }

  static Box get _box => Hive.box(boxName);

  static Future<void> save({
    required List<DeviceModel> devices,
    required Map<String, DeviceHomeSnapshot> snapshots,
  }) async {
    await ensureBox();
    await _box.put(
      _devicesKey,
      jsonEncode(devices.map((d) => d.toJson()).toList()),
    );
    await _box.put(
      _snapshotsKey,
      jsonEncode({
        for (final e in snapshots.entries) e.key: e.value.toJson(),
      }),
    );
    await _box.put(_savedAtKey, DateTime.now().toIso8601String());
  }

  static Future<({List<DeviceModel> devices, Map<String, DeviceHomeSnapshot> snapshots, DateTime? savedAt})?>
      load() async {
    await ensureBox();
    final rawDevices = _box.get(_devicesKey) as String?;
    if (rawDevices == null || rawDevices.isEmpty) return null;
    try {
      final list = (jsonDecode(rawDevices) as List<dynamic>)
          .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final rawSnaps = _box.get(_snapshotsKey) as String?;
      final snaps = <String, DeviceHomeSnapshot>{};
      if (rawSnaps != null && rawSnaps.isNotEmpty) {
        final map = jsonDecode(rawSnaps) as Map<String, dynamic>;
        for (final e in map.entries) {
          snaps[e.key] = DeviceHomeSnapshot.fromJson(
            e.value as Map<String, dynamic>,
          );
        }
      }
      final savedRaw = _box.get(_savedAtKey) as String?;
      return (
        devices: list,
        snapshots: snaps,
        savedAt: savedRaw != null ? DateTime.tryParse(savedRaw) : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    await ensureBox();
    await _box.deleteAll([_devicesKey, _snapshotsKey, _savedAtKey]);
  }
}

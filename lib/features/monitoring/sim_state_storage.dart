import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:spy_love/core/storage/secure_hive.dart';

/// Persists last known SIM slots for insert/remove diffing on the monitored device.
class SimStateStorage {
  SimStateStorage._();

  static const _boxName = 'sim_state';
  static const _snapshotKey = 'last_snapshot';

  static Future<Box<dynamic>> _box() => SecureHive.openBox(_boxName);

  static Future<Map<int, Map<String, dynamic>>> loadSnapshot() async {
    final box = await _box();
    final raw = box.get(_snapshotKey) as String?;
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) =>
            MapEntry(int.parse(key), Map<String, dynamic>.from(value as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveSnapshot(
    Map<int, Map<String, dynamic>> snapshot,
  ) async {
    final box = await _box();
    final encoded = snapshot.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await box.put(_snapshotKey, jsonEncode(encoded));
  }
}

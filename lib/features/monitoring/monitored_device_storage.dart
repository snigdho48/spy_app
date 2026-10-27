import 'package:hive_flutter/hive_flutter.dart';

/// Persists the monitored device id for background sync on the device-owner account.
class MonitoredDeviceStorage {
  MonitoredDeviceStorage._();

  static const _boxName = 'monitored_device';
  static const _deviceIdKey = 'device_id';

  static Future<Box<dynamic>> _box() => Hive.openBox(_boxName);

  static Future<void> saveDeviceId(String deviceId) async {
    final box = await _box();
    await box.put(_deviceIdKey, deviceId);
  }

  static Future<String?> getDeviceId() async {
    final box = await _box();
    return box.get(_deviceIdKey) as String?;
  }

  static Future<void> clear() async {
    final box = await _box();
    await box.delete(_deviceIdKey);
  }
}

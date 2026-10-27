import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _fingerprintKey = 'device_fingerprint';

/// Stable per-install device ID sent to the pairing API.
class DeviceFingerprintStorage {
  DeviceFingerprintStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _fingerprintKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final fingerprint = const Uuid().v4();
    await _storage.write(key: _fingerprintKey, value: fingerprint);
    return fingerprint;
  }
}

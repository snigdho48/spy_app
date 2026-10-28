import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:spy_love/core/debug/app_log.dart';

/// Opens Hive boxes with AES encryption. The cipher key lives in
/// [FlutterSecureStorage] and is generated on first run.
///
/// Migration: an existing unencrypted box is read once, deleted from disk,
/// then rewritten under encryption so returning users are not locked out.
/// If migration fails, the plaintext box is left alone and opened without
/// encryption so the user is not locked out (logged in debug only).
abstract final class SecureHive {
  static const _keyStorageKey = 'hive_aes_key_v1';
  static const _migratedFlagPrefix = 'hive_enc_migrated_v1_';

  static final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static HiveAesCipher? _cipher;

  static Future<HiveAesCipher> _cipherOrCreate() async {
    final existing = _cipher;
    if (existing != null) return existing;

    final stored = await _secure.read(key: _keyStorageKey);
    late final Uint8List bytes;
    if (stored != null && stored.isNotEmpty) {
      bytes = Uint8List.fromList(base64Decode(stored));
    } else {
      bytes = Uint8List.fromList(Hive.generateSecureKey());
      await _secure.write(key: _keyStorageKey, value: base64Encode(bytes));
    }
    return _cipher = HiveAesCipher(bytes);
  }

  static Future<String> _migratedFlag(String name) async =>
      '$_migratedFlagPrefix$name';

  /// Opens [name] with AES when possible. Falls back to plaintext on migrate
  /// failure so existing installs are never locked out.
  static Future<Box<dynamic>> openBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<dynamic>(name);
    }

    final cipher = await _cipherOrCreate();
    final flagKey = await _migratedFlag(name);
    final alreadyMigrated = await _secure.read(key: flagKey) == '1';

    if (alreadyMigrated) {
      return Hive.openBox<dynamic>(name, encryptionCipher: cipher);
    }

    final exists = await Hive.boxExists(name);
    if (!exists) {
      final box = await Hive.openBox<dynamic>(name, encryptionCipher: cipher);
      await _secure.write(key: flagKey, value: '1');
      return box;
    }

    // Existing on-disk box: prefer migrate plaintext → encrypted.
    try {
      final plain = await Hive.openBox<dynamic>(name);
      final snapshot = Map<dynamic, dynamic>.from(plain.toMap());
      await plain.close();
      await Hive.deleteBoxFromDisk(name);
      final encrypted = await Hive.openBox<dynamic>(
        name,
        encryptionCipher: cipher,
      );
      if (snapshot.isNotEmpty) {
        await encrypted.putAll(snapshot);
      }
      await _secure.write(key: flagKey, value: '1');
      return encrypted;
    } catch (e, stack) {
      AppLog.e(
        'Hive plaintext migrate for "$name" failed; trying encrypted open',
        e,
        stack,
      );
    }

    // Box may already be encrypted (partial prior run) or plaintext open failed.
    try {
      final box = await Hive.openBox<dynamic>(name, encryptionCipher: cipher);
      await _secure.write(key: flagKey, value: '1');
      return box;
    } catch (e, stack) {
      AppLog.e(
        'Encrypted open for "$name" failed; falling back to plaintext',
        e,
        stack,
      );
      // Do not set the migrated flag — retry encryption next launch.
      return Hive.openBox<dynamic>(name);
    }
  }
}

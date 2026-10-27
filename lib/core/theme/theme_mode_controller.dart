import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persists light / dark / system preference for Consent Horizon screens.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController() {
    final raw = _box.get(_key, defaultValue: 'system') as String;
    _mode = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static const _boxName = 'settings';
  static const _key = 'theme_mode';

  static Future<void> ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  Box get _box => Hive.box(_boxName);

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    await _box.put(
      _key,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
    notifyListeners();
  }
}

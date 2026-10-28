import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:spy_love/core/storage/secure_hive.dart';

/// Tracks whether the consent/opt-in first-run walkthrough has been finished.
class OnboardingController extends ChangeNotifier {
  OnboardingController() {
    _completed = _box.get(_key, defaultValue: false) as bool;
  }

  static const _boxName = 'settings';
  static const _key = 'onboarding_completed_v1';

  static Future<void> ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await SecureHive.openBox(_boxName);
    }
  }

  Box get _box => Hive.box(_boxName);

  bool _completed = false;
  bool get completed => _completed;

  Future<void> complete() async {
    _completed = true;
    await _box.put(_key, true);
    notifyListeners();
  }
}

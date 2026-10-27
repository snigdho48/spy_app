import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/network/one_request_config.dart';
import 'package:spy_love/core/theme/theme_mode_controller.dart';
import 'package:spy_love/firebase_options.dart';

/// Runs all startup initialization before [runApp].
abstract final class AppBootstrap {
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    await _dropForeignStoredHosts();
    await ThemeModeController.ensureBox();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, stack) {
      debugPrint('Firebase init failed: $e\n$stack');
    }

    try {
      OneRequestConfig.setup();
    } catch (e, stack) {
      debugPrint('OneRequest setup failed: $e\n$stack');
    }
  }

  /// Deletes bare URL values whose host is not the compiled API host.
  ///
  /// The base URL is only [AppConfig.apiBaseUrl] / [AppConfig.wsBaseUrl].
  /// Nothing in the app reads a stored host. This still removes a leftover
  /// value so it cannot be picked up later.
  static Future<void> _dropForeignStoredHosts() async {
    const names = ['settings', 'monitored_device', 'sim_state'];
    for (final name in names) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox<dynamic>(name);
      }
      final box = Hive.box<dynamic>(name);
      final drop = <dynamic>[
        for (final key in box.keys)
          if (box.get(key) case final String value)
            if (AppConfig.isForeignStoredHost(value)) key,
      ];
      if (drop.isNotEmpty) {
        await box.deleteAll(drop);
      }
    }
  }
}

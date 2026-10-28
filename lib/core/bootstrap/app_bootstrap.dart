import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/debug/app_log.dart';
import 'package:spy_love/core/network/certificate_pinning.dart';
import 'package:spy_love/core/network/one_request_config.dart';
import 'package:spy_love/core/storage/secure_hive.dart';
import 'package:spy_love/core/theme/theme_mode_controller.dart';
import 'package:spy_love/core/onboarding/onboarding_controller.dart';
import 'package:spy_love/firebase_options.dart';

/// Runs all startup initialization before [runApp].
abstract final class AppBootstrap {
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    await _dropForeignStoredHosts();
    await ThemeModeController.ensureBox();
    await OnboardingController.ensureBox();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, stack) {
      AppLog.e('Firebase init failed', e, stack);
    }

    try {
      OneRequestConfig.setup();
      CertificatePinning.applyToSharedClient();
    } catch (e, stack) {
      AppLog.e('OneRequest setup failed', e, stack);
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
        await SecureHive.openBox(name);
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

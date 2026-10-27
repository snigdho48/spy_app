import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:spy_love/core/network/one_request_config.dart';
import 'package:spy_love/core/theme/theme_mode_controller.dart';
import 'package:spy_love/firebase_options.dart';

/// Runs all startup initialization before [runApp].
abstract final class AppBootstrap {
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
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
}

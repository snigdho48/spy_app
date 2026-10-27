import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spy_love/app/app.dart';
import 'package:spy_love/app/core/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  await AppBootstrap.init();
  runApp(const SpyLoveApp());
}

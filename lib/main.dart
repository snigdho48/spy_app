import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spy_love/app/app.dart';
import 'package:spy_love/core/bootstrap/app_bootstrap.dart';
import 'package:spy_love/core/debug/app_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLog.e('FlutterError', details.exceptionAsString());
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.e('Uncaught error', error, stack);
    return true;
  };

  await AppBootstrap.init();
  runApp(const SpyLoveApp());
}

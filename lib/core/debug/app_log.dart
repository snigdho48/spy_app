import 'package:flutter/foundation.dart';

/// Release-safe logger. Every method is a no-op when [kDebugMode] is false.
///
/// Never pass tokens, passwords, message bodies, contact lists, or other
/// sensitive payloads — even in debug, prefer opaque ids / counts.
abstract final class AppLog {
  static void d(String message, [Object? error, StackTrace? stack]) {
    if (!kDebugMode) return;
    final buf = StringBuffer(message);
    if (error != null) buf.write(': $error');
    if (stack != null) buf.write('\n$stack');
    debugPrint(buf.toString());
  }

  static void e(String message, [Object? error, StackTrace? stack]) {
    d(message, error, stack);
  }
}

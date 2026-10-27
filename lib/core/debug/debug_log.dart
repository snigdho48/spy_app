import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Debug session logger — writes NDJSON to workspace log file.
abstract final class DebugLog {
  static const _sessionId = '5dd7fc';
  static const _logPath = r'D:\Spy_LOve\debug-5dd7fc.log';

  static void write({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, Object?> data = const {},
    String runId = 'pre-fix',
  }) {
    if (kIsWeb) return;

    final entry = <String, Object?>{
      'sessionId': _sessionId,
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // #region agent log
    try {
      File(_logPath).writeAsStringSync(
        '${jsonEncode(entry)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
    // #endregion
  }
}

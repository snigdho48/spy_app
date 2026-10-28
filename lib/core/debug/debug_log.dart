import 'package:spy_love/core/debug/app_log.dart';

/// Legacy session logger. Prefer [AppLog]. Kept so older call sites compile;
/// writes nothing in release and never logs sensitive payloads.
abstract final class DebugLog {
  static void write({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, Object?> data = const {},
    String runId = 'pre-fix',
  }) {
    AppLog.d('[$hypothesisId/$runId] $location: $message');
  }
}

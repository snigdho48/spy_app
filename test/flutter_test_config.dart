import 'dart:async';

/// Shared test bootstrap. Inter loads from network when available; otherwise
/// ThemeData falls back (see google_fonts warnings). Prefer `flutter run` on a
/// device with network for true Inter rendering.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}

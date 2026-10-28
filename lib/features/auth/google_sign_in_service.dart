import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:spy_love/core/config/app_config.dart';

/// Wraps Google Sign-In and returns ID tokens for backend verification.
class GoogleSignInService {
  static bool _initialized = false;

  /// Call once at app startup before [runApp].
  static Future<void> initAtStartup() async {
    if (_initialized || kIsWeb) return;

    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return;
    }

    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId,
    );
    _initialized = true;
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await initAtStartup();
    }
  }

  /// Returns a Google ID token, or null if the user cancelled.
  Future<String?> getIdToken() async {
    await ensureInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google Sign-In is not supported on this platform',
      );
    }

    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw StateError('Google did not return an ID token');
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        throw StateError(
          'Google Sign-In native plugin is not loaded. '
          'Stop the app, run "flutter clean", then "flutter run" for a full rebuild.',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    await GoogleSignIn.instance.signOut();
  }
}

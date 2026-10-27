import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_colors.dart';

/// Central app configuration — env vars, API, network, and UI constants.
/// Colors come from Consent Horizon [AppColors] — do not hard-code elsewhere.
abstract final class AppConfig {
  static const String appName = 'Spy Love';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://spy.way2points.com/api/v1',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://spy.way2points.com/ws/v1/events/',
  );

  /// Builds the per-session live screen WebSocket URL from [wsBaseUrl].
  ///
  /// [sessionWsPath] is the `ws_url` the backend returns for a screen-share
  /// session, e.g. `ws/v1/screen/<id>/`. An absolute URL keeps only its path.
  /// The events suffix of [wsBaseUrl] is stripped so the screen socket uses
  /// the compiled host, even when the payload names a different one.
  static String screenWsUrl(String sessionWsPath) {
    final origin = wsBaseUrl.replaceFirst(RegExp(r'/ws/v1/events/?$'), '');
    return '$origin${screenPath(sessionWsPath)}';
  }

  /// Path portion of a screen `ws_url`. Absolute URLs drop their host.
  static String screenPath(String sessionWsPath) {
    final raw = sessionWsPath.trim();
    if (raw.isEmpty) return '/';
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      final path = parsed.path.isEmpty ? '/' : parsed.path;
      return path.startsWith('/') ? path : '/$path';
    }
    return raw.startsWith('/') ? raw : '/$raw';
  }

  /// True when [value] is a single absolute URL on a host other than the
  /// compiled API or websocket host. Those values are leftover overrides and
  /// are never used as [apiBaseUrl] or [wsBaseUrl].
  static bool isForeignStoredHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        trimmed.contains(' ') ||
        trimmed.contains('\n')) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' &&
        scheme != 'https' &&
        scheme != 'ws' &&
        scheme != 'wss') {
      return false;
    }
    final host = uri.host.toLowerCase();
    final compiled = {
      Uri.parse(apiBaseUrl).host.toLowerCase(),
      Uri.parse(wsBaseUrl).host.toLowerCase(),
    };
    return !compiled.contains(host);
  }

  static const Duration apiTimeout = Duration(seconds: 30);
  static const int apiMaxRetries = 1;
  static const Duration apiRetryDelay = Duration(seconds: 1);
  static const int apiMaxRedirects = 5;
  static const int maxErrorMessageLength = 220;

  static const Color primaryColor = AppColors.primary;
  static const Color primaryColorDark = AppColors.primaryPressed;
  static const Color loaderOverlayColor = AppColors.loaderOverlay;

  static const Color successColor = AppColors.success;
  static const Color infoColor = AppColors.info;
  static const Color warningColor = AppColors.warning;
  static const Color dangerColor = AppColors.danger;

  static const Color lightSurface = AppColors.lightSurface;
  static const Color lightOnSurface = AppColors.lightPrimaryText;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color darkOnSurface = AppColors.darkOnSurface;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;

  static Color onSurface(BuildContext context) =>
      isDark(context) ? darkOnSurface : lightOnSurface;

  static Color scrim(BuildContext context) =>
      isDark(context) ? loaderOverlayColor : const Color(0x66101828);

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };

  /// Web OAuth client ID — required on Android to obtain an ID token.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '812706609654-gpjc0h45pa7o8vuva977v9gl75ig1n71.apps.googleusercontent.com',
  );
}

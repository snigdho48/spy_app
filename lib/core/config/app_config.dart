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
  /// session, e.g. `ws/v1/screen/<id>/`. The events suffix of [wsBaseUrl] is
  /// stripped so the screen socket shares the same host/scheme.
  static String screenWsUrl(String sessionWsPath) {
    final origin = wsBaseUrl.replaceFirst(RegExp(r'/ws/v1/events/?$'), '');
    final path =
        sessionWsPath.startsWith('/') ? sessionWsPath : '/$sessionWsPath';
    return '$origin$path';
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

  /// JSON headers for API calls. The ngrok browser-warning header is added
  /// only when [apiBaseUrl] still points at an ngrok host (a `--dart-define`
  /// override). Production traffic does not send it.
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        if (apiBaseUrl.contains('ngrok')) 'ngrok-skip-browser-warning': 'true',
      };

  /// Web OAuth client ID — required on Android to obtain an ID token.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1098260301010-vifp1hi2vohcjfd30no1uj75h1t2hpu1.apps.googleusercontent.com',
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:one_request/one_request.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/network/spy_request_chrome.dart';

/// OneRequest / EasyLoading setup — kept out of [main.dart].
abstract final class OneRequestConfig {
  static void setup() {
    _configureLoading();
    _configureApi();
    _configureErrorHandler();
    _configureCustomBuilders();
  }

  static void _configureLoading() {
    // Fallback only. Requests use [SpyRequestOverlay], not EasyLoading's toast.
    OneRequest.loadingconfig(
      backgroundColor: AppConfig.darkSurface,
      indicatorColor: AppConfig.primaryColor,
      progressColor: AppConfig.primaryColor,
      textColor: AppConfig.darkOnSurface,
      maskType: EasyLoadingMaskType.custom,
      maskColor: AppConfig.loaderOverlayColor,
      radius: 18,
      fontSize: 14,
      indicatorSize: 28,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      indicator: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppConfig.primaryColor,
        ),
      ),
      success: const Icon(
        Icons.check_circle_outline,
        color: AppConfig.successColor,
      ),
      error: const Icon(Icons.error_outline, color: AppConfig.dangerColor),
      info: const Icon(Icons.info_outline, color: AppConfig.infoColor),
    );
  }

  static void _configureApi() {
    OneRequest.configure(
      baseUrl: AppConfig.apiBaseUrl,
      headers: AppConfig.defaultHeaders,
      enableErrorLogger: kDebugMode,
      enableResponseLogger: kDebugMode,
      enableLoader: false,
      enableErrorOverlay: false,
      enableSuccessOverlay: false,
      sanitizeErrorMessages: true,
      maxErrorMessageLength: AppConfig.maxErrorMessageLength,
      showStatusCodeInError: false,
      defaultTimeoutSeconds: AppConfig.apiTimeout.inSeconds,
      defaultMaxRetries: AppConfig.apiMaxRetries,
      defaultRetryDelay: AppConfig.apiRetryDelay,
      defaultMaxRedirects: AppConfig.apiMaxRedirects,
      enableWebSocket: true,
      wsAutoReconnect: true,
    );
    OneRequest.setConnectivity(
      ui: ConnectivityUi.none,
      showOnline: false,
      builder: (context, status, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (!status.online)
              const Align(
                alignment: Alignment.bottomCenter,
                child: SpyOfflineBar(),
              ),
          ],
        );
      },
    );
  }

  static void _configureErrorHandler() {
    OneRequest.setErrorHandler(
      handler: (body, status, url) {
        // A non-JSON body (e.g. an HTML 404 page from a misrouted request)
        // must never be echoed to the user. Map common statuses to short,
        // safe copy and never surface a raw host/path or markup.
        if (body.isEmpty) {
          final code = status ?? 0;
          if (code == 404) {
            return 'Server path not found. Please update the app.';
          }
          if (code >= 500) {
            return 'The server had a problem. Please try again shortly.';
          }
          return 'Request failed';
        }
        final error = body['error'];
        if (error is Map) {
          return error['message']?.toString() ?? 'Request failed';
        }
        return body['detail']?.toString() ??
            body['message']?.toString() ??
            'Request failed';
      },
    );
  }

  static void _configureCustomBuilders() {
    LoadingStuff.setCustomBuilders(
      loadingBuilder: (context, status) => SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppConfig.primaryColor,
          backgroundColor: AppConfig.surface(context),
        ),
      ),
      errorBuilder: (context, message) =>
          Icon(Icons.error_outline, color: AppConfig.dangerColor),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spy_love/core/debug/app_log.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/features/alerts/repositories/alert_repository.dart';

/// Background isolate handler. Must be a top-level / static entry point.
/// The system tray shows notification-type messages automatically; we only
/// log here so the background isolate stays light.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLog.d('Push', 'Background message ${message.messageId}');
}

const _pushTokenIdKey = 'push_token_server_id';

/// Owns the FCM lifecycle: consent-gated permission, token registration on
/// login / refresh, unregister on logout, and foreground + tap handling that
/// surfaces a local notification and deep-links into the alert's device.
class PushService {
  PushService(this._alerts);

  final AlertRepository _alerts;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'spy_love_alerts',
    'Alerts',
    description: 'Geofence, SIM, battery and SOS alerts for consented devices.',
    importance: Importance.high,
  );

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  /// Sets up local-notification plugin + FCM stream listeners. Safe to call
  /// more than once. Does NOT request permission (that is consent-gated).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _local.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
        ),
        onDidReceiveNotificationResponse: (response) =>
            _handlePayload(response.payload),
      );

      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      _onMessageSub = FirebaseMessaging.onMessage.listen(_showLocal);
      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _handlePayload(jsonEncode(m.data)),
      );
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_sendToken(token)),
      );

      // Cold start from a notification tap.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handlePayload(jsonEncode(initial.data));
      }
    } catch (e, stack) {
      AppLog.e('Push init failed', e, stack);
    }
  }

  /// Shows a consent-style rationale, then requests OS notification permission.
  /// Returns true when authorized. Call this right after login.
  Future<bool> requestPermissionWithRationale(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stay notified, with consent'),
        content: const Text(
          'Spy Love can alert you when a consented device enters or leaves a '
          'safe zone, changes SIM, hits low battery, or triggers SOS. '
          'Notifications only reflect feeds the device owner has agreed to '
          'share. You can turn them off anytime in system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enable alerts'),
          ),
        ],
      ),
    );
    if (proceed != true) return false;

    final settings = await FirebaseMessaging.instance.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) await registerToken();
    return granted;
  }

  /// Fetches the current token and registers it with the backend.
  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _sendToken(token);
    } catch (e, stack) {
      AppLog.e('Push token fetch failed', e, stack);
    }
  }

  Future<void> _sendToken(String token) async {
    final result = await _alerts.registerPushToken(
      token: token,
      platform: _platform,
    );
    await result.fold(
      (id) => _storage.write(key: _pushTokenIdKey, value: id),
      (_) async {},
    );
  }

  /// Unregisters the device token on logout.
  Future<void> unregister() async {
    try {
      final id = await _storage.read(key: _pushTokenIdKey);
      if (id != null && id.isNotEmpty) {
        await _alerts.deletePushToken(id);
      }
      await _storage.delete(key: _pushTokenIdKey);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e, stack) {
      AppLog.e('Push unregister failed', e, stack);
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'New alert';
    final body = notification?.body ?? message.data['body'] ?? '';
    await _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Deep-links a tapped notification into the Alerts surface. The dashboard's
  /// Alerts tab resolves the device from [DashboardController].
  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      AppLog.d('Push', 'Opened alert ${data['alert_id'] ?? data['device_id']}');
      AppNavigator.popUntilHome();
    } catch (_) {
      // Non-JSON payloads are ignored.
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
  }
}

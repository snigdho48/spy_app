import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/features/auth/google_sign_in_service.dart';
import 'package:spy_love/features/monitoring/monitoring_service.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_service.dart';
import 'package:spy_love/core/network/api_service.dart';
import 'package:spy_love/core/network/network_service.dart';
import 'package:spy_love/core/network/screen_stream_client.dart';
import 'package:spy_love/core/network/spy_request_chrome.dart';
import 'package:spy_love/core/permissions/permission_service.dart';
import 'package:spy_love/core/storage/device_fingerprint_storage.dart';
import 'package:spy_love/core/storage/token_storage.dart';
import 'package:spy_love/features/audit/repositories/audit_repository.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/auth/repositories/auth_repository.dart';
import 'package:spy_love/features/devices/controllers/dashboard_controller.dart';
import 'package:spy_love/features/devices/repositories/device_repository.dart';
import 'package:spy_love/features/devices/repositories/keyword_repository.dart';
import 'package:spy_love/features/devices/repositories/safe_zone_repository.dart';
import 'package:spy_love/features/devices/repositories/event_repository.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_share_repository.dart';
import 'package:spy_love/features/consent/controllers/pairing_controller.dart';
import 'package:spy_love/features/subscription/controllers/subscription_controller.dart';
import 'package:spy_love/features/subscription/repositories/subscription_repository.dart';
import 'package:spy_love/core/theme/theme_mode_controller.dart';

class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => TokenStorage()),
        ChangeNotifierProvider(create: (_) => ThemeModeController()),
        ChangeNotifierProvider(create: (_) => RequestOverlayController()),
        ChangeNotifierProvider(create: (_) => NetworkService()),
        ChangeNotifierProvider(create: (_) => PermissionService()),
        Provider(create: (_) => GoogleSignInService()),
        Provider(create: (_) => DeviceFingerprintStorage()),
        ProxyProvider3<NetworkService, TokenStorage, RequestOverlayController, ApiService>(
          update: (_, network, tokens, overlay, previous) =>
              previous ?? ApiService(network, tokens, overlay),
        ),
        ProxyProvider3<ApiService, TokenStorage, GoogleSignInService, AuthRepository>(
          update: (_, api, tokens, google, previous) =>
              previous ?? AuthRepository(api, tokens, google),
        ),
        ProxyProvider<ApiService, DeviceRepository>(
          update: (_, api, previous) => previous ?? DeviceRepository(api),
        ),
        ProxyProvider<ApiService, SafeZoneRepository>(
          update: (_, api, previous) => previous ?? SafeZoneRepository(api),
        ),
        ProxyProvider<ApiService, KeywordRepository>(
          update: (_, api, previous) => previous ?? KeywordRepository(api),
        ),
        ProxyProvider<ApiService, EventRepository>(
          update: (_, api, previous) => previous ?? EventRepository(api),
        ),
        ProxyProvider<ApiService, ScreenShareRepository>(
          update: (_, api, previous) => previous ?? ScreenShareRepository(api),
        ),
        ProxyProvider<TokenStorage, ScreenStreamClient>(
          update: (_, tokens, previous) => previous ?? ScreenStreamClient(tokens),
        ),
        ChangeNotifierProxyProvider<ScreenShareRepository, ScreenShareService>(
          create: (context) =>
              ScreenShareService(context.read<ScreenShareRepository>()),
          update: (_, repo, previous) => previous ?? ScreenShareService(repo),
        ),
        ProxyProvider<ApiService, SubscriptionRepository>(
          update: (_, api, previous) => previous ?? SubscriptionRepository(api),
        ),
        ProxyProvider<ApiService, AuditRepository>(
          update: (_, api, previous) => previous ?? AuditRepository(api),
        ),
        ProxyProvider5<
            EventRepository,
            DeviceRepository,
            SafeZoneRepository,
            ScreenShareService,
            ScreenStreamClient,
            MonitoringService>(
          update: (_, events, devices, safeZones, screenShare, screenStream,
                  previous) =>
              previous ??
              MonitoringService(
                events,
                devices,
                safeZones,
                screenShare,
                screenStream,
              ),
        ),
        ChangeNotifierProxyProvider<SubscriptionRepository, SubscriptionController>(
          create: (context) => SubscriptionController(context.read<SubscriptionRepository>()),
          update: (_, repo, controller) => controller ?? SubscriptionController(repo),
        ),
        ChangeNotifierProxyProvider2<AuthRepository, MonitoringService, AuthController>(
          create: (context) => AuthController(
            context.read<AuthRepository>(),
            context.read<MonitoringService>(),
          ),
          update: (_, repo, monitoring, controller) =>
              controller ?? AuthController(repo, monitoring),
        ),
        ChangeNotifierProxyProvider4<
            DeviceRepository,
            EventRepository,
            PermissionService,
            AuthController,
            DashboardController>(
          create: (context) => DashboardController(
            context.read<DeviceRepository>(),
            context.read<EventRepository>(),
            context.read<PermissionService>(),
            context.read<AuthController>(),
          ),
          update: (_, repo, events, permissions, auth, controller) =>
              controller ?? DashboardController(repo, events, permissions, auth),
        ),
        ChangeNotifierProxyProvider4<
            DeviceRepository,
            DeviceFingerprintStorage,
            PermissionService,
            AuthController,
            PairingController>(
          create: (context) => PairingController(
            context.read<DeviceRepository>(),
            context.read<DeviceFingerprintStorage>(),
            context.read<PermissionService>(),
            context.read<AuthController>(),
            context.read<MonitoringService>(),
            context.read<DashboardController>(),
          ),
          update: (context, repo, fingerprint, permissions, auth, controller) =>
              controller ??
              PairingController(
                repo,
                fingerprint,
                permissions,
                auth,
                context.read<MonitoringService>(),
                context.read<DashboardController>(),
              ),
        ),
      ],
      child: _ControllerBinder(child: child),
    );
  }
}

class _ControllerBinder extends StatefulWidget {
  const _ControllerBinder({required this.child});

  final Widget child;

  @override
  State<_ControllerBinder> createState() => _ControllerBinderState();
}

class _ControllerBinderState extends State<_ControllerBinder> {
  bool _bound = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bound) return;
    _bound = true;
    final auth = context.read<AuthController>();
    final subscription = context.read<SubscriptionController>();
    auth.bindSubscription(subscription);
    subscription.bindAuth(auth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      auth.restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

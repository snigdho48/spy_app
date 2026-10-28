import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/storage/token_storage.dart';
import 'package:spy_love/features/audit/views/audit_log_view.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/auth/views/auth_view.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/repositories/device_repository.dart';
import 'package:spy_love/features/devices/views/dashboard_view.dart';
import 'package:spy_love/features/alerts/repositories/alert_repository.dart';
import 'package:spy_love/features/devices/controllers/device_detail_controller.dart';
import 'package:spy_love/features/devices/controllers/fleet_overview_controller.dart';
import 'package:spy_love/features/devices/controllers/activity_timeline_controller.dart';
import 'package:spy_love/features/devices/repositories/event_repository.dart';
import 'package:spy_love/features/devices/repositories/safe_zone_repository.dart';
import 'package:spy_love/features/devices/views/device_detail_view.dart';
import 'package:spy_love/features/devices/views/event_detail_view.dart';
import 'package:spy_love/features/devices/views/fleet_overview_view.dart';
import 'package:spy_love/features/devices/views/activity_timeline_view.dart';
import 'package:spy_love/features/devices/views/installed_apps_view.dart';
import 'package:spy_love/features/devices/views/location_map_fullscreen_view.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/theme/app_colors.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/consent/views/pairing_complete_view.dart';
import 'package:spy_love/features/consent/views/pairing_initiate_view.dart';
import 'package:spy_love/features/consent/views/pairing_start_view.dart';
import 'package:spy_love/features/consent/views/permission_setup_view.dart';
import 'package:spy_love/features/subscription/views/subscription_plans_view.dart';

abstract final class AppRoutes {
  static const login = '/';
  static const dashboard = '/';
  static const pairing = '/pairing';
  static const pairingInitiate = '/pairing/initiate';
  static const pairingComplete = '/pairing/complete';
  static const permissionSetup = '/pairing/permissions';
  static const subscriptions = '/subscriptions';
  static const deviceDetail = '/devices/detail';
  static const eventDetail = '/events/detail';
  static const audit = '/audit';
  static const installedApps = '/apps/installed';
  static const locationMapFullscreen = '/devices/location-map';
  static const fleetOverview = '/devices/overview';
  static const activityTimeline = '/devices/activity';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case pairing:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const PairingStartView(),
        );
      case pairingInitiate:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const PairingInitiateView(),
        );
      case pairingComplete:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const PairingCompleteView(),
        );
      case permissionSetup:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const PermissionSetupView(),
        );
      case subscriptions:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SubscriptionPlansView(),
        );
      case audit:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AuditLogView(),
        );
      case installedApps:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const InstalledAppsView(),
        );
      case deviceDetail:
        final device = settings.arguments as DeviceModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => ChangeNotifierProvider(
            create: (ctx) => DeviceDetailController(
              ctx.read<DeviceRepository>(),
              ctx.read<EventRepository>(),
              ctx.read<SafeZoneRepository>(),
              device,
              ctx.read<TokenStorage>(),
            ),
            child: const DeviceDetailView(),
          ),
        );
      case eventDetail:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => EventDetailView(
            args: settings.arguments as Map<String, dynamic>? ?? {},
          ),
        );
      case fleetOverview:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => ChangeNotifierProvider(
            create: (ctx) => FleetOverviewController(
              ctx.read<DeviceRepository>(),
              ctx.read<EventRepository>(),
              ctx.read<AlertRepository>(),
            ),
            child: const FleetOverviewView(),
          ),
        );
      case activityTimeline:
        final device = settings.arguments as DeviceModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => ChangeNotifierProvider(
            create: (ctx) => ActivityTimelineController(
              device,
              ctx.read<EventRepository>(),
              ctx.read<AlertRepository>(),
            ),
            child: const ActivityTimelineView(),
          ),
        );
      case locationMapFullscreen:
        final args = settings.arguments as LocationMapFullscreenArgs;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LocationMapFullscreenView(args: args),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AuthGate(),
        );
    }
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (auth.isRestoring) return const _SessionRestoreSplash();
        if (!auth.isLoggedIn) return const AuthView();
        return const DashboardView();
      },
    );
  }
}

class _SessionRestoreSplash extends StatelessWidget {
  const _SessionRestoreSplash();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      backgroundColor: tokens.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: tokens.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Restoring your session…',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

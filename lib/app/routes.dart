import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/storage/token_storage.dart';
import 'package:spy_love/features/audit/views/audit_log_view.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/auth/views/auth_view.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/repositories/device_repository.dart';
import 'package:spy_love/features/devices/views/dashboard_view.dart';
import 'package:spy_love/features/devices/controllers/device_detail_controller.dart';
import 'package:spy_love/features/devices/repositories/event_repository.dart';
import 'package:spy_love/features/devices/views/device_detail_view.dart';
import 'package:spy_love/features/devices/views/event_detail_view.dart';
import 'package:spy_love/features/devices/views/installed_apps_view.dart';
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
              device,
              ctx.read<TokenStorage>(),
            ),
            child: const DeviceDetailView(),
          ),
        );
      case eventDetail:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => EventDetailView(args: settings.arguments as Map<String, dynamic>? ?? {}),
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
        if (!auth.isLoggedIn) return const AuthView();
        return const DashboardView();
      },
    );
  }
}

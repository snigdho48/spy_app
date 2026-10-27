import 'package:flutter/material.dart';
import 'package:one_request/one_request.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/app_providers.dart';
import 'package:spy_love/app/core/config/app_config.dart';
import 'package:spy_love/app/core/monitoring/screen_sharing_indicator.dart';
import 'package:spy_love/app/core/network/spy_request_chrome.dart';
import 'package:spy_love/app/core/navigation/app_navigator.dart';
import 'package:spy_love/app/core/theme/app_theme.dart';
import 'package:spy_love/app/core/theme/theme_mode_controller.dart';
import 'package:spy_love/app/core/widgets/responsive_scaffold.dart';
import 'package:spy_love/app/routes/app_routes.dart';

class SpyLoveApp extends StatelessWidget {
  const SpyLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      child: Consumer<ThemeModeController>(
        builder: (context, themeMode, _) {
          return MaterialApp(
            title: AppConfig.appName,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode.mode,
            debugShowCheckedModeBanner: false,
            navigatorKey: AppNavigator.key,
            scaffoldMessengerKey: AppNavigator.messengerKey,
            builder: OneRequest.wrap((context, child) {
              return ScaledTextScope(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child ?? const SizedBox.shrink(),
                    const SpyRequestOverlay(),
                    // Persistent monitored-device "screen is being shared"
                    // banner. Inert unless a live screen session is active.
                    const ScreenSharingIndicator(),
                  ],
                ),
              );
            }),
            home: const AuthGate(),
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}

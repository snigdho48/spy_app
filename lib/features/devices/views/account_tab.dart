import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/network/network_service.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/core/theme/theme_mode_controller.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/features/devices/widgets/family_circle_switcher.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/auth/views/account_security_card.dart';
import 'package:spy_love/features/devices/controllers/dashboard_controller.dart';
import 'package:spy_love/features/devices/views/safe_zones_card.dart';
import 'package:spy_love/features/devices/views/sharing_pause_card.dart';
import 'package:spy_love/features/consent/models/consent_scope.dart';
import 'package:spy_love/features/subscription/views/workspace_setup_card.dart';
import 'package:spy_love/app/routes.dart';
import 'package:spy_love/features/update/update_service.dart';
import 'package:spy_love/features/update/views/update_dialog.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final dashboard = context.watch<DashboardController>();
    final network = context.watch<NetworkService>();
    final tokens = context.tokens;
    final user = auth.user;
    final sub = user?.subscription;

    return AppPage(
      children: [
        const PageIntro(
          title: 'Account & security',
          subtitle:
              'Workspace identity, linked sign-in, and mutual consent controls',
        ),
        if (!network.isConnected) ...[
          OfflineBanner(onRetry: network.refreshStatus),
          const SizedBox(height: AppSpacing.md),
        ],
        const WorkspaceSetupCard(),
        const FamilyCircleCard(),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: tokens.successSoft,
          elevated: false,
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: tokens.consented),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consent is up to date',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dashboard.devices.length} devices • ${dashboard.attentionCount == 0 ? 'no expired permissions' : '${dashboard.attentionCount} need review'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge.consent(active: dashboard.attentionCount == 0),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SharingPauseCard(),
        const SafeZonesCard(),
        Text(
          'Transparency ledger',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: ConsentScope.all.take(6).map((scope) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scope.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            scope.description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: tokens.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const StatusBadge(label: 'Managed', tone: StatusTone.info),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Per-device consent is set during pairing and can be reviewed on each device.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
        ),
        const SizedBox(height: 24),
        if (sub != null) ...[
          Text('Plan & billing', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => AppNavigator.toNamed(AppRoutes.subscriptions),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT PLAN',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub.planName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Up to ${sub.maxDevices} active devices',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: tokens.secondaryText),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        AppCard(
          onTap: () => AppNavigator.toNamed(AppRoutes.audit),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mutual audit log',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Pairing, consent, and who accessed what',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tokens.secondaryText),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (user != null) ...[
          Text(
            user.fullName.isNotEmpty ? user.fullName : user.email,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            [
              user.email,
              user.tenantName,
              user.role,
            ].whereType<String>().join(' · '),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: 16),
        ],
        const AccountSecurityCard(),
        const SizedBox(height: AppSpacing.lg),
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Consumer<ThemeModeController>(
          builder: (context, themeMode, _) {
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Home and device screens follow Consent Horizon light and dark tokens.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {themeMode.mode},
                    onSelectionChanged: (value) =>
                        themeMode.setMode(value.first),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Check for updates',
          icon: Icons.system_update,
          variant: AppButtonVariant.secondary,
          onPressed: () async {
            final shown = await UpdateDialog.maybeShow(
              context,
              UpdateService(),
            );
            if (!shown) {
              AppNavigator.snackbar(
                'Up to date',
                'You already have the latest version.',
                icon: Icons.check_circle_outline,
              );
            }
          },
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Sign out',
          icon: Icons.logout,
          variant: AppButtonVariant.secondary,
          onPressed: auth.logout,
        ),
      ],
    );
  }
}

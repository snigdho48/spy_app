import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/app/routes.dart';

class SubscriptionSummaryCard extends StatelessWidget {
  const SubscriptionSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final user = auth.user;
        final sub = user?.subscription;
        if (user == null || user.needsWorkspace || sub == null) {
          return const SizedBox.shrink();
        }

        return Card(
          child: ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text('${sub.planName} plan'),
            subtitle: Text(
              'Up to ${sub.maxDevices} devices · ${sub.eventRetentionDays}-day history',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppNavigator.toNamed(AppRoutes.subscriptions),
          ),
        );
      },
    );
  }
}

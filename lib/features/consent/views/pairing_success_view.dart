import 'package:flutter/material.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';

/// Stitch pairing success — shown after mutual consent is confirmed.
class PairingSuccessView extends StatelessWidget {
  const PairingSuccessView({
    super.key,
    required this.deviceName,
    required this.scopeCount,
  });

  final String deviceName;
  final int scopeCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pairing complete'),
            Text(
              '● CONSENTED LINK',
              style: theme.textTheme.labelSmall?.copyWith(
                color: tokens.consented,
              ),
            ),
          ],
        ),
      ),
      body: AppPage(
        children: [
          AppCard(
            color: tokens.successSoft,
            elevated: false,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 40,
                    color: tokens.consented,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Mutual consent locked',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$deviceName is now sharing with your Family Circle.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                StatusBadge(
                  label: '$scopeCount scopes consented',
                  tone: StatusTone.success,
                  pulse: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: tokens.primarySoft,
            elevated: false,
            child: Text(
              'Both devices keep a persistent status notification so sharing stays visible. Either person can revoke scopes from Account or Device detail anytime.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Go to Home',
            icon: Icons.home_outlined,
            onPressed: AppNavigator.popUntilHome,
          ),
        ],
      ),
    );
  }
}

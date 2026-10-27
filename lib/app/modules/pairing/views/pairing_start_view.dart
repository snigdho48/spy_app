import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/core/navigation/app_navigator.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_button.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/app_page.dart';
import 'package:spy_love/app/core/widgets/status_badge.dart';
import 'package:spy_love/app/modules/auth/controllers/auth_controller.dart';
import 'package:spy_love/app/routes/app_routes.dart';

/// Stitch "Pairing Entry Hub" — role pick + consent sequence.
class PairingStartView extends StatelessWidget {
  const PairingStartView({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    final content = AppPage(
      children: [
        Row(
          children: [
            Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'CONSENT VERIFICATION HUB',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Add a Monitored Device',
          style: theme.textTheme.headlineMedium?.copyWith(
            letterSpacing: -0.2,
            height: 1.15,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Select the role of this physical device to begin cryptographically verified pairing.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: tokens.secondaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: tokens.primarySoft,
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tokens.successSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.handshake_outlined, color: tokens.consented, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '● Mutual Consent Required',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: tokens.consentedLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Spy Love strictly operates with explicit permission. The target phone will display an active pairing banner and permanent consent status.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: tokens.consented),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Auditable Ledger & Revocation active by default',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                'TRANSPARENT PAIRING SEQUENCE',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tokens.secondaryText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Text(
              'Step 1 of 3',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const _PairingSteps(),
        const SizedBox(height: AppSpacing.lg),
        _RoleCard(
          icon: Icons.person_add_alt_1_outlined,
          iconSoft: tokens.primarySoft,
          title: 'Admin Monitor',
          badge: 'Option A',
          badgeTone: StatusTone.info,
          body:
              "This phone is the Guardian. Pair and monitor a family member's phone with bilateral visibility controls.",
          buttonLabel: 'Start Monitor Pairing',
          buttonVariant: AppButtonVariant.primary,
          onPressed: () {
            final auth = context.read<AuthController>();
            if (auth.user?.needsWorkspace ?? true) {
              AppNavigator.snackbar(
                'Workspace required',
                'Create a monitoring workspace before approving devices.',
              );
              return;
            }
            AppNavigator.toNamed(AppRoutes.pairingComplete);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _RoleCard(
          icon: Icons.phonelink_setup_outlined,
          iconSoft: tokens.successSoft,
          title: 'Monitored Device',
          badge: 'Option B',
          badgeTone: StatusTone.success,
          body:
              'This phone is being Monitored. Display a pairing QR or short code to link with your family circle.',
          buttonLabel: 'Generate Monitored Phone Code',
          buttonVariant: AppButtonVariant.soft,
          buttonIcon: Icons.qr_code_2_outlined,
          onPressed: () => AppNavigator.toNamed(AppRoutes.pairingInitiate),
        ),
      ],
    );

    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Spy Love · Pair'),
            Text(
              '● MUTUAL TRANSPARENCY ACTIVE',
              style: theme.textTheme.labelSmall?.copyWith(color: tokens.consented),
            ),
          ],
        ),
      ),
      body: content,
    );
  }
}

class _PairingSteps extends StatelessWidget {
  const _PairingSteps();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final steps = const [
      (Icons.pin_outlined, '1. Generate Secure Code', true),
      (Icons.description_outlined, '2. Review Scope Limits', false),
      (Icons.draw_outlined, '3. Agree Mutual Sign', false),
    ];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(height: 1, color: tokens.border),
            ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: steps[i].$3
                        ? theme.colorScheme.primary
                        : tokens.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    steps[i].$1,
                    size: 20,
                    color: steps[i].$3 ? Colors.white : tokens.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  steps[i].$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: steps[i].$3
                        ? theme.colorScheme.primary
                        : tokens.secondaryText,
                    fontWeight: steps[i].$3 ? FontWeight.w700 : FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.iconSoft,
    required this.title,
    required this.badge,
    required this.badgeTone,
    required this.body,
    required this.buttonLabel,
    required this.buttonVariant,
    required this.onPressed,
    this.buttonIcon,
  });

  final IconData icon;
  final Color iconSoft;
  final String title;
  final String badge;
  final StatusTone badgeTone;
  final String body;
  final String buttonLabel;
  final AppButtonVariant buttonVariant;
  final VoidCallback onPressed;
  final IconData? buttonIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSpacing.touchMin,
                height: AppSpacing.touchMin,
                decoration: BoxDecoration(
                  color: iconSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              StatusBadge(label: badge, tone: badgeTone, showDot: false),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: buttonLabel,
            icon: buttonIcon ?? Icons.arrow_forward,
            variant: buttonVariant,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

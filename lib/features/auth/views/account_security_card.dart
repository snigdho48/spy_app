import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_text_field.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/l10n/app_localizations.dart';

class AccountSecurityCard extends StatelessWidget {
  const AccountSecurityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) return const SizedBox.shrink();

        final methods = user.authMethods;
        final canLinkGoogle = !methods.hasGoogle;
        final canSetPassword = !methods.hasPassword;
        final tokens = context.tokens;
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.signInSecurityTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.signInSecurityBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatusBadge(
                    label: methods.hasPassword
                        ? 'Email enabled'
                        : 'Email not set',
                    tone: methods.hasPassword
                        ? StatusTone.success
                        : StatusTone.warning,
                    pulse: false,
                  ),
                  StatusBadge(
                    label: methods.hasGoogle
                        ? 'Google linked'
                        : 'Google not linked',
                    tone: methods.hasGoogle
                        ? StatusTone.success
                        : StatusTone.neutral,
                    pulse: false,
                  ),
                ],
              ),
              if (auth.errorMessage.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  auth.errorMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (!canLinkGoogle && !canSetPassword) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Email/password and Google are both enabled for this account.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                if (canSetPassword)
                  AppButton(
                    label: 'Set password for email login',
                    icon: Icons.password,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _showSetPasswordDialog(context),
                  ),
                if (canSetPassword && canLinkGoogle)
                  const SizedBox(height: AppSpacing.sm),
                if (canLinkGoogle)
                  AppButton(
                    label: 'Link Google account',
                    icon: Icons.link,
                    loading: auth.isGoogleLoading,
                    onPressed: auth.isGoogleLoading
                        ? null
                        : auth.linkGoogleAccount,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSetPasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose a password so you can sign in with email as well as Google.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: ctx.tokens.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: passwordController,
                label: 'New password',
                obscureText: true,
                validator: (v) =>
                    v == null || v.length < 10 ? 'Min 10 characters' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: confirmController,
                label: 'Confirm password',
                obscureText: true,
                validator: (v) {
                  if (v != passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              await context.read<AuthController>().setPassword(
                passwordController.text,
              );
            },
            child: const Text('Save password'),
          ),
        ],
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
  }
}

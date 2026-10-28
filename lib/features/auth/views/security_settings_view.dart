import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/auth/controllers/security_controller.dart';
import 'package:spy_love/features/auth/models/totp_models.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/app_text_field.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';

class SecuritySettingsView extends StatefulWidget {
  const SecuritySettingsView({super.key});

  @override
  State<SecuritySettingsView> createState() => _SecuritySettingsViewState();
}

class _SecuritySettingsViewState extends State<SecuritySettingsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SecurityController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityController>();
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final enabled = security.status?.enabled ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
      ),
      body: AppPage(
        children: [
          const PageIntro(
            title: 'Two-factor authentication',
            subtitle:
                'Protect your account with an authenticator app. Recovery codes let you sign in if you lose the device.',
          ),
          if (security.errorMessage.isNotEmpty) ...[
            Text(
              security.errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Authenticator app (TOTP)',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    StatusBadge(
                      label: enabled ? 'Enabled' : 'Off',
                      tone: enabled ? StatusTone.success : StatusTone.neutral,
                      pulse: false,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  enabled
                      ? 'A code from your authenticator is required after password sign-in.'
                      : 'Add a second step so a stolen password alone cannot open your family circle.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
                if (security.status != null && enabled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${security.status!.recoveryCodesRemaining} recovery codes remaining',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (!enabled && security.enrollment == null)
                  Semantics(
                    button: true,
                    label: 'Enable two-factor authentication',
                    child: AppButton(
                      label: 'Enable 2FA',
                      icon: Icons.phonelink_lock_outlined,
                      onPressed: security.isLoading ? null : security.startEnroll,
                    ),
                  ),
                if (enabled) ...[
                  AppButton(
                    label: 'Disable 2FA',
                    icon: Icons.lock_open_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _confirmDisable(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Regenerate recovery codes',
                    icon: Icons.refresh,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _regenerate(context),
                  ),
                ],
              ],
            ),
          ),
          if (security.enrollment != null) ...[
            const SizedBox(height: AppSpacing.md),
            _EnrollmentCard(enrollment: security.enrollment!),
          ],
          if (security.recoveryCodes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _RecoveryCodesCard(codes: security.recoveryCodes),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Active sessions', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Devices signed in with your account. Revoke any you do not recognize.',
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: AppSpacing.md),
          if (security.sessionsLoading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (security.sessions.isEmpty)
            AppCard(
              child: Text(
                'No active sessions reported yet. Sign in again after the sessions API is available to populate this list.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
            )
          else ...[
            ...security.sessions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.devices_other_outlined,
                          color: tokens.secondaryText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.deviceLabel,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  if (s.isCurrent)
                                    const StatusBadge(
                                      label: 'This device',
                                      tone: StatusTone.info,
                                      pulse: false,
                                    ),
                                ],
                              ),
                              if (s.ipAddress != null && s.ipAddress!.isNotEmpty)
                                Text(
                                  s.ipAddress!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: tokens.secondaryText,
                                  ),
                                ),
                              if (s.lastUsedAt != null)
                                Text(
                                  'Last used ${s.lastUsedAt!.toLocal()}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: tokens.secondaryText,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!s.isCurrent)
                          Semantics(
                            button: true,
                            label: 'Revoke session ${s.deviceLabel}',
                            child: IconButton(
                              icon: const Icon(Icons.logout),
                              tooltip: 'Revoke',
                              onPressed: () => security.revokeSession(s.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              button: true,
              label: 'Sign out of all other devices',
              child: AppButton(
                label: 'Sign out everywhere else',
                icon: Icons.phonelink_erase_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: security.sessions.any((s) => !s.isCurrent)
                    ? () => security.revokeOtherSessions()
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDisable(BuildContext context) async {
    final password = TextEditingController();
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable two-factor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirm with your password or a current authenticator code.'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: password,
              label: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: code,
              label: 'Or authenticator / recovery code',
              keyboardType: TextInputType.visiblePassword,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<SecurityController>().disable(
            password: password.text,
            code: code.text,
          );
    }
    password.dispose();
    code.dispose();
  }

  Future<void> _regenerate(BuildContext context) async {
    final password = TextEditingController();
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New recovery codes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This invalidates previous codes. Confirm with password or TOTP.'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: password,
              label: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: code,
              label: 'Or authenticator code',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<SecurityController>().regenerateRecovery(
            password: password.text,
            code: code.text,
          );
    }
    password.dispose();
    code.dispose();
  }
}

class _EnrollmentCard extends StatefulWidget {
  const _EnrollmentCard({required this.enrollment});
  final TotpEnrollment enrollment;

  @override
  State<_EnrollmentCard> createState() => _EnrollmentCardState();
}

class _EnrollmentCardState extends State<_EnrollmentCard> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enrollment = widget.enrollment;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final security = context.watch<SecurityController>();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scan this QR code', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Semantics(
              image: true,
              label: 'Authenticator QR code',
              child: QrImageView(
                data: enrollment.otpauthUri,
                version: QrVersions.auto,
                size: 200,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: theme.colorScheme.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: tokens.primaryText,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            enrollment.secret,
            style: theme.textTheme.labelLarge,
          ),
          Text(
            'Or enter this secret manually in your authenticator app.',
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _code,
            label: '6-digit code',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Verify & enable',
                  onPressed: () async {
                    await security.confirmEnroll(_code.text);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.secondary,
                onPressed: security.clearEnrollment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecoveryCodesCard extends StatelessWidget {
  const _RecoveryCodesCard({required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recovery codes', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Store these offline. Each code works once.',
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: AppSpacing.md),
          ...codes.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SelectableText(c, style: theme.textTheme.titleSmall),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Copy all',
            icon: Icons.copy,
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codes.join('\n')));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recovery codes copied')),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Done',
            onPressed: () => context.read<SecurityController>().clearRecoveryCodes(),
          ),
        ],
      ),
    );
  }
}

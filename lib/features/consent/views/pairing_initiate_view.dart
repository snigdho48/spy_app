import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/app_text_field.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/features/consent/controllers/pairing_controller.dart';
import 'package:spy_love/features/consent/models/pairing_initiate_result.dart';
import 'package:spy_love/app/routes.dart';

class PairingInitiateView extends StatelessWidget {
  const PairingInitiateView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PairingController>();
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pair monitored device'),
            Text(
              'MUTUAL TRANSPARENCY PROTOCOL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (context) {
          if (controller.isLoading && controller.activePairing == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: LoadingSkeleton(lines: 4),
            );
          }

          final pairing = controller.activePairing;
          if (pairing == null) return _buildSetupForm(context, controller);
          return _buildPairingDisplay(context, controller, pairing, tokens);
        },
      ),
    );
  }

  Widget _buildSetupForm(BuildContext context, PairingController controller) {
    final tokens = context.tokens;
    return ListView(
      padding: context.pagePadding,
      children: [
        Text(
          'Connect to Family Circle',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Generate a code. Someone with a workspace confirms consent scopes before any data is shared.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: controller.deviceNameController,
          label: 'Device name',
          hint: "e.g. Maya's Pixel",
        ),
        if (controller.errorMessage.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            controller.errorMessage,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Continue to permissions',
          icon: Icons.security,
          onPressed: () async {
            final ok = await AppNavigator.toNamed(AppRoutes.permissionSetup);
            if (ok == true) {
              await controller.initiatePairing();
            }
          },
        ),
      ],
    );
  }

  Widget _buildPairingDisplay(
    BuildContext context,
    PairingController controller,
    PairingInitiateResult pairing,
    AppTokens tokens,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.startActivationWatch(pairing.deviceId);
    });

    final expired = pairing.expiresAt.isBefore(DateTime.now());
    final theme = Theme.of(context);

    return ListView(
      padding: context.pagePadding,
      children: [
        Row(
          children: [
            const StatusBadge(
              label: 'Pairing in Progress',
              tone: StatusTone.info,
              pulse: true,
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(
              label: 'Mutual Consent',
              tone: StatusTone.success,
              pulse: false,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Connect to Family Circle', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Scanning or entering this code lets your guardian confirm selected diagnostics with mutual visibility.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: tokens.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (expired)
          AppCard(
            color: tokens.dangerSoft,
            elevated: false,
            child: Column(
              children: [
                Icon(
                  Icons.timer_off_outlined,
                  size: 40,
                  color: tokens.revokeText,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Pairing code expired',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Generate a new code to continue. Expired codes cannot be scanned or entered.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Generate a new code',
                  icon: Icons.refresh,
                  onPressed: () {
                    controller.clearActivePairing();
                    controller.initiatePairing();
                  },
                ),
              ],
            ),
          )
        else ...[
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'TARGET DEVICE QR',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                    const Spacer(),
                    const StatusBadge(
                      label: 'Ready to bind',
                      tone: StatusTone.info,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: tokens.border),
                  ),
                  child: QrImageView(
                    data: pairing.qrPayload,
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
                const SizedBox(height: AppSpacing.sm),
                Text(
                  pairing.qrPayload,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
                    Icon(
                      Icons.handshake_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Listening for Guardian scan…',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    _ExpiryCountdown(expiresAt: pairing.expiresAt),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Handshake channel: TLS encrypted · Active polling',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scanning or verification in progress. Mutual consent is required before any telemetry syncs.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Or enter 6-digit short code',
                      style: theme.textTheme.labelMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: pairing.pairingCode),
                        );
                        AppNavigator.snackbar('Copied', 'Pairing code copied');
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Tap to copy'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pairing.pairingCode.replaceAll('-', ' - '),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          letterSpacing: 4,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    AppButton(
                      label: 'Copy',
                      icon: Icons.copy,
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: pairing.pairingCode),
                        );
                        AppNavigator.snackbar('Copied', 'Pairing code copied');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _ExpiryCountdown(expiresAt: pairing.expiresAt),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (controller.isWatchingApproval)
            AppCard(
              color: tokens.warningSoft,
              elevated: false,
              child: Column(
                children: [
                  const StatusBadge(
                    label: 'Listening for Guardian scan…',
                    tone: StatusTone.warning,
                    pulse: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Waiting for mutual consent…',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'You return home automatically once the approver confirms consent scopes.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Share pairing link via SMS / WhatsApp',
            icon: Icons.ios_share,
            onPressed: () {
              final text =
                  'Join my Spy Love Family Circle with code ${pairing.pairingCode}.\n${pairing.qrPayload}';
              SharePlus.instance.share(ShareParams(text: text));
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: tokens.successSoft,
            elevated: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: tokens.consented),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zero Hidden Tracking Guarantee',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You approve scopes before telemetry syncs. A persistent status notification stays visible.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Cancel pairing',
          icon: Icons.close,
          variant: AppButtonVariant.destructive,
          onPressed: () {
            controller.clearActivePairing();
            AppNavigator.pop();
          },
        ),
      ],
    );
  }
}

class _ExpiryCountdown extends StatefulWidget {
  const _ExpiryCountdown({required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<_ExpiryCountdown> createState() => _ExpiryCountdownState();
}

class _ExpiryCountdownState extends State<_ExpiryCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return Text(
        'Expired',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.tokens.revokeText),
      );
    }
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final hours = remaining.inHours;
    final label = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: context.tokens.secondaryText),
        const SizedBox(width: 6),
        Text(
          'Code expires in $label',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.tokens.secondaryText),
        ),
      ],
    );
  }
}

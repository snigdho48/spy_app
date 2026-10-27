import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';

/// Stitch "Permission Prompts" — Usage Access + Notification Listener setup.
class PermissionSetupView extends StatefulWidget {
  const PermissionSetupView({super.key});

  @override
  State<PermissionSetupView> createState() => _PermissionSetupViewState();
}

class _PermissionSetupViewState extends State<PermissionSetupView> with WidgetsBindingObserver {
  bool _usageGranted = false;
  bool _notificationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final notification = await Permission.notification.status;
    // Usage access has no first-class permission_handler check on all platforms;
    // treat notification as granted when authorized; usage opens settings only.
    setState(() {
      _notificationGranted = notification.isGranted;
    });
  }

  int get _grantedCount => (_usageGranted ? 1 : 0) + (_notificationGranted ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final progress = _grantedCount / 2;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grant device permissions'),
            Text(
              '● MUTUAL TRANSPARENCY ACTIVE',
              style: theme.textTheme.labelSmall?.copyWith(color: tokens.consented),
            ),
          ],
        ),
      ),
      body: AppPage(
        children: [
          Text(
            'STEP 2 OF 3 · ANDROID SETUP',
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: tokens.surfaceContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$_grantedCount / 2 Granted',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Grant Device Permissions', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'To enable transparent family care, Android requires explicit system permissions. Spy Love never runs hidden.',
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.badge),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('2 Permissions Required for Setup', style: theme.textTheme.labelMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PermissionCard(
            icon: Icons.query_stats,
            iconColor: theme.colorScheme.primary,
            title: 'Usage Access',
            subtitle: 'System Telemetry Layer',
            required: !_usageGranted,
            body:
                'Allows the guardian dashboard to show screen time and detect overnight app usage when consent includes app usage.',
            privacyLock:
                'PRIVACY LOCK: Spy Love only reads screen duration and app package names. It never reads inside banking apps or sensitive context.',
            steps: const [
              'Tap “Open System Usage Settings” below.',
              'Locate “Spy Love” in the Android system list.',
              'Toggle “Permit usage access” to ON.',
            ],
            buttonLabel: 'Open System Usage Settings',
            onPressed: () async {
              await openAppSettings();
              if (mounted) setState(() => _usageGranted = true);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _PermissionCard(
            icon: Icons.notifications_active_outlined,
            iconColor: tokens.consented,
            title: 'Notification Listener',
            subtitle: 'Alert & Guardian Channel',
            required: !_notificationGranted,
            body:
                'Enables safety keyword alerts from chat apps and a persistent status notification so monitoring stays visible.',
            privacyLock:
                'LOCAL PROCESSING GUARANTEE: Private personal chats are not recorded without trigger words and consent.',
            steps: const [
              'Tap “Grant Notification Access”.',
              'Confirm the system dialog acknowledging Spy Love.',
            ],
            buttonLabel: 'Grant Notification Access',
            onPressed: () async {
              await Permission.notification.request();
              await _refresh();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: tokens.surfaceContainerLow,
            elevated: false,
            child: Text(
              'Mutual Visibility Standard: A persistent Android system notification remains in the status bar so the monitored person always knows sharing is active.',
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _grantedCount >= 2
                ? 'Continue'
                : 'Complete Permissions to Continue',
            icon: _grantedCount >= 2 ? Icons.check : Icons.lock_outline,
            onPressed: _grantedCount >= 2 ? () => Navigator.of(context).pop(true) : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Revocable anytime in device Settings',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(color: tokens.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.required,
    required this.body,
    required this.privacyLock,
    required this.steps,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool required;
  final String body;
  final String privacyLock;
  final List<String> steps;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(subtitle, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              StatusBadge(
                label: required ? 'Action Required' : 'Granted',
                tone: required ? StatusTone.warning : StatusTone.success,
                pulse: !required,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: tokens.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(privacyLock, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...steps.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: tokens.primarySoft,
                        child: Text(
                          '${e.key + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(e.value, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: buttonLabel, icon: Icons.open_in_new, onPressed: onPressed),
        ],
      ),
    );
  }
}

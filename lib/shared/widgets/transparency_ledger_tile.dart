import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';

/// Consent Horizon "Transparency Ledger" row — what is captured, for whom, revoke action.
class TransparencyLedgerTile extends StatelessWidget {
  const TransparencyLedgerTile({
    super.key,
    required this.scopeLabel,
    required this.consumerLabel,
    required this.timestampLabel,
    this.icon = Icons.sensors,
    this.onRevoke,
  });

  final String scopeLabel;
  final String consumerLabel;
  final String timestampLabel;
  final IconData icon;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.chipInner),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timestampLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(scopeLabel, style: theme.textTheme.bodyMedium),
                Text(
                  consumerLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ),
          ),
          if (onRevoke != null)
            AppButton(
              label: 'Revoke',
              variant: AppButtonVariant.destructive,
              expand: false,
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }
}

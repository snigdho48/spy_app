import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';

class ConsentRow extends StatelessWidget {
  const ConsentRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onChanged,
    this.showSwitch = true,
    this.statusLabel,
    this.statusTone,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final bool showSwitch;
  final String? statusLabel;
  final StatusTone? statusTone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  StatusBadge(
                    label: statusLabel!,
                    tone: statusTone ?? StatusTone.neutral,
                    pulse: statusTone == StatusTone.success,
                  ),
                ],
              ],
            ),
          ),
          if (showSwitch) Switch.adaptive(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

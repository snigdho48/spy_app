import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    this.icon,
    this.onTap,
    this.badge,
    this.badgeTone = StatusTone.info,
  });

  final String label;
  final String value;
  final String caption;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? badge;
  final StatusTone badgeTone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                StatusBadge(
                  label: badge!,
                  tone: badgeTone,
                  showDot: false,
                  pulse: false,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(height: 1.05),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: tokens.secondaryText,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

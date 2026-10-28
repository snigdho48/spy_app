import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/alerts/models/alert_model.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';

class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert, required this.onTap});

  final AlertModel alert;
  final VoidCallback onTap;

  Color _toneColor(BuildContext context) {
    final tokens = context.tokens;
    return switch (alert.severity.tone) {
      StatusTone.success => tokens.consented,
      StatusTone.warning => tokens.pending,
      StatusTone.danger => tokens.revoked,
      StatusTone.info => Theme.of(context).colorScheme.primary,
      StatusTone.neutral => tokens.dormant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final accent = _toneColor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        label:
            '${alert.isRead ? "" : "Unread. "}${alert.severity.label} alert: '
            '${alert.title}. ${alert.typeLabel}.',
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(alert.type.icon, color: accent, size: 20),
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
                            alert.title.isEmpty
                                ? alert.typeLabel
                                : alert.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: alert.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!alert.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (alert.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        alert.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.secondaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusBadge(
                          label: alert.severity.label,
                          tone: alert.severity.tone,
                          showDot: false,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TimestampLabel(alert.createdAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';

class EventListTile extends StatelessWidget {
  const EventListTile({
    super.key,
    required this.title,
    required this.preview,
    required this.timestamp,
    this.onTap,
    this.icon = Icons.notifications_none,
    this.leadingColor,
  });

  final String title;
  final String preview;
  final DateTime timestamp;
  final VoidCallback? onTap;
  final IconData icon;
  final Color? leadingColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: leadingColor ?? Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TimestampLabel(timestamp),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: tokens.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

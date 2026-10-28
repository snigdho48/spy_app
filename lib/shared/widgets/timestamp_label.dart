import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spy_love/core/theme/app_tokens.dart';

class TimestampLabel extends StatelessWidget {
  const TimestampLabel(this.timestamp, {super.key, this.compact = true});

  final DateTime timestamp;
  final bool compact;

  static String format(DateTime timestamp, {bool compact = true}) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final time = DateFormat.jm().format(local);
    if (!compact) {
      return DateFormat.yMMMd().add_jms().format(local);
    }
    if (sameDay) return 'Today • $time';
    if (now.difference(local).inDays == 1) return 'Yesterday • $time';
    return '${DateFormat.MMMd().format(local)} • $time';
  }

  static String relative(DateTime timestamp) {
    final delta = DateTime.now().difference(timestamp.toLocal());
    if (delta.inSeconds < 45) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      format(timestamp, compact: compact),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.tokens.secondaryText),
    );
  }
}

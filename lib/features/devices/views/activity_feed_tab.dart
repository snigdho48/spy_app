import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/adaptive_metric_row.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/metric_card.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';
import 'package:spy_love/features/devices/models/keyword_model.dart';
import 'package:spy_love/features/devices/repositories/keyword_repository.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';
import 'package:spy_love/features/devices/views/event_detail_view.dart';
import 'package:spy_love/app/routes.dart';

enum ActivityFeedKind { calls, sms, messages }

enum _SmsFilter { all, flagged, known }

enum _CallFilter { all, incoming, outgoing, blocked }

/// Stitch-aligned Calls / SMS / Messages activity feed.
class ActivityFeedTab extends StatefulWidget {
  const ActivityFeedTab({
    super.key,
    required this.kind,
    required this.events,
    required this.isLoading,
    required this.onOpen,
    this.companionCount = 0,
  });

  final ActivityFeedKind kind;
  final List<DeviceEventModel> events;
  final bool isLoading;
  final ValueChanged<DeviceEventModel> onOpen;
  final int companionCount;

  @override
  State<ActivityFeedTab> createState() => _ActivityFeedTabState();
}

class _ActivityFeedTabState extends State<ActivityFeedTab> {
  _SmsFilter _smsFilter = _SmsFilter.all;
  _CallFilter _callFilter = _CallFilter.all;
  List<KeywordModel> _keywords = const [];
  bool _keywordsLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.kind == ActivityFeedKind.sms ||
        widget.kind == ActivityFeedKind.messages) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadKeywords());
    }
  }

  Future<void> _loadKeywords() async {
    setState(() => _keywordsLoading = true);
    final result = await context.read<KeywordRepository>().list();
    if (!mounted) return;
    result.fold(
      (words) => setState(() {
        _keywords = words;
        _keywordsLoading = false;
      }),
      (_) => setState(() => _keywordsLoading = false),
    );
  }

  int get _incomingCount =>
      widget.events.where((e) => _callDirection(e) == 'incoming').length;
  int get _outgoingCount =>
      widget.events.where((e) => _callDirection(e) == 'outgoing').length;
  int get _blockedCount => widget.events.where((e) => _isBlocked(e)).length;
  int get _flaggedCount =>
      widget.events.where((e) => _isFlagged(e, _keywords)).length;
  int get _knownCount => widget.events.where(_isKnown).length;

  List<DeviceEventModel> get _filtered {
    final events = widget.events;
    return switch (widget.kind) {
      ActivityFeedKind.calls => switch (_callFilter) {
        _CallFilter.all => events,
        _CallFilter.incoming =>
          events.where((e) => _callDirection(e) == 'incoming').toList(),
        _CallFilter.outgoing =>
          events.where((e) => _callDirection(e) == 'outgoing').toList(),
        _CallFilter.blocked => events.where(_isBlocked).toList(),
      },
      ActivityFeedKind.sms || ActivityFeedKind.messages => switch (_smsFilter) {
        _SmsFilter.all => events,
        _SmsFilter.flagged =>
          events.where((e) => _isFlagged(e, _keywords)).toList(),
        _SmsFilter.known => events.where(_isKnown).toList(),
      },
    };
  }

  static String _callDirection(DeviceEventModel event) {
    final raw = (event.payload['direction'] ?? event.payload['type'] ?? '')
        .toString()
        .toLowerCase();
    if (raw.contains('block') ||
        raw.contains('spam') ||
        raw.contains('screen')) {
      return 'blocked';
    }
    if (raw == 'in' || raw.contains('incoming') || raw.contains('inbound')) {
      return 'incoming';
    }
    if (raw == 'out' || raw.contains('outgoing') || raw.contains('outbound')) {
      return 'outgoing';
    }
    if (raw.contains('miss')) return 'missed';
    return raw;
  }

  static bool _isBlocked(DeviceEventModel event) {
    final d = _callDirection(event);
    if (d == 'blocked') return true;
    final flags = [
      event.payload['blocked'],
      event.payload['is_blocked'],
      event.payload['spam'],
      event.payload['screened'],
    ];
    return flags.any((f) => f == true || f?.toString().toLowerCase() == 'true');
  }

  static bool _isFlagged(
    DeviceEventModel event, [
    List<KeywordModel> keywords = const [],
  ]) {
    final contact = event.contact;
    if (contact.isFlagged) return true;
    final p = event.payload;
    if (p['flagged'] == true ||
        p['keyword_hit'] == true ||
        p['alert'] == true) {
      return true;
    }
    final text = [
      p['preview'],
      p['body'],
      p['message'],
      p['keyword'],
      p['tags'],
    ].whereType<Object>().join(' ').toLowerCase();
    for (final keyword in keywords) {
      if (keyword.word.isNotEmpty &&
          text.contains(keyword.word.toLowerCase())) {
        return true;
      }
    }
    return text.contains('flag') ||
        text.contains('keyword') ||
        text.contains('redact') ||
        text.contains('alert') ||
        text.contains('****');
  }

  static bool _isKnown(DeviceEventModel event) {
    final contact = event.contact;
    if (contact.isKnown) return true;
    final name = (contact.contactName ?? '').trim();
    if (name.isEmpty) return false;
    final digitsOnly = RegExp(r'^[\d\s+\-().]+$').hasMatch(name);
    return !digitsOnly;
  }

  Future<void> _openKeywordManager(BuildContext context) async {
    final repo = context.read<KeywordRepository>();
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.md,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Manage keywords',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'New keyword',
                      hintText: 'e.g. help',
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      final word = controller.text.trim();
                      if (word.isEmpty) return;
                      final result = await repo.create(word);
                      result.fold((_) {
                        controller.clear();
                        setSheet(() {});
                      }, (_) {});
                      await _loadKeywords();
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Add keyword',
                    icon: Icons.add,
                    onPressed: () async {
                      final word = controller.text.trim();
                      if (word.isEmpty) return;
                      final result = await repo.create(word);
                      result.fold((_) => controller.clear(), (_) {});
                      await _loadKeywords();
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._keywords.map(
                    (k) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(k.chipLabel),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await repo.delete(k.id);
                          await _loadKeywords();
                          setSheet(() {});
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    await _loadKeywords();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final kind = widget.kind;
    final events = widget.events;

    if (widget.isLoading && events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LoadingSkeleton(lines: 5),
      );
    }

    final filtered = _filtered;

    return ListView(
      padding: context.pagePadding,
      children: [
        _PrivacyMandateBanner(kind: kind),
        const SizedBox(height: AppSpacing.md),
        if (kind == ActivityFeedKind.calls) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's Call Activity",
                  style: theme.textTheme.titleLarge?.copyWith(
                    letterSpacing: -0.15,
                    height: 1.2,
                  ),
                ),
              ),
              StatusBadge(
                label: '${events.length} Total Interactions',
                tone: StatusTone.info,
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AdaptiveMetricRow(
            children: [
              MetricCard(
                label: 'Incoming',
                value: '$_incomingCount',
                caption: events.isEmpty
                    ? '—'
                    : '${((_incomingCount / events.length) * 100).round()}% volume',
                icon: Icons.call_received,
              ),
              MetricCard(
                label: 'Outgoing',
                value: '$_outgoingCount',
                caption: events.isEmpty
                    ? '—'
                    : '${((_outgoingCount / events.length) * 100).round()}% volume',
                icon: Icons.call_made,
              ),
              MetricCard(
                label: 'Blocked',
                value: '$_blockedCount',
                caption: 'Spam screened',
                icon: Icons.block,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _FilterChip(
                label: 'All (${events.length})',
                selected: _callFilter == _CallFilter.all,
                onTap: () => setState(() => _callFilter = _CallFilter.all),
              ),
              _FilterChip(
                label: 'Incoming ($_incomingCount)',
                selected: _callFilter == _CallFilter.incoming,
                onTap: () => setState(() => _callFilter = _CallFilter.incoming),
              ),
              _FilterChip(
                label: 'Outgoing ($_outgoingCount)',
                selected: _callFilter == _CallFilter.outgoing,
                onTap: () => setState(() => _callFilter = _CallFilter.outgoing),
              ),
              _FilterChip(
                label: 'Blocked ($_blockedCount)',
                selected: _callFilter == _CallFilter.blocked,
                onTap: () => setState(() => _callFilter = _CallFilter.blocked),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (kind == ActivityFeedKind.sms ||
            kind == ActivityFeedKind.messages) ...[
          AppCard(
            color: tokens.successSoft,
            elevated: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: tokens.consented),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Safe Keyword Guard Active',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const StatusBadge(
                      label: 'On-Device Zero-Knowledge',
                      tone: StatusTone.success,
                      showDot: false,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  kind == ActivityFeedKind.sms
                      ? 'Personal conversation text is protected. Only emergency keywords and verified contacts are analyzed locally with consent.'
                      : 'Chat alerts use notification access with consent — not a full message archive.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveMetricRow(
            children: [
              MetricCard(
                label: kind == ActivityFeedKind.sms
                    ? 'Logged SMS'
                    : 'Chat alerts',
                value: '${events.length}',
                caption: 'With consent',
                icon: Icons.chat_bubble_outline,
              ),
              MetricCard(
                label: 'Safety alerts',
                value: '$_flaggedCount',
                caption: 'Keyword guard',
                icon: Icons.shield_outlined,
              ),
              MetricCard(
                label: kind == ActivityFeedKind.sms ? 'Unknown' : 'Apps',
                value: '${widget.companionCount}',
                caption: kind == ActivityFeedKind.sms ? 'Senders' : 'Sources',
                icon: Icons.qr_code_scanner,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _FilterChip(
                label: kind == ActivityFeedKind.sms
                    ? 'All SMS (${events.length})'
                    : 'All (${events.length})',
                selected: _smsFilter == _SmsFilter.all,
                onTap: () => setState(() => _smsFilter = _SmsFilter.all),
              ),
              _FilterChip(
                label: 'Flagged Keywords ($_flaggedCount)',
                selected: _smsFilter == _SmsFilter.flagged,
                onTap: () => setState(() => _smsFilter = _SmsFilter.flagged),
              ),
              _FilterChip(
                label: 'Known Contacts ($_knownCount)',
                selected: _smsFilter == _SmsFilter.known,
                onTap: () => setState(() => _smsFilter = _SmsFilter.known),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                switch (kind) {
                  ActivityFeedKind.calls => 'RECENT TELEPHONY HISTORY',
                  ActivityFeedKind.sms => 'MESSAGE SUMMARIES',
                  ActivityFeedKind.messages => 'CHAT ALERT FEED',
                },
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tokens.secondaryText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Text(
              kind == ActivityFeedKind.calls ? 'Filtered' : 'Live Feed',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (filtered.isEmpty)
          EmptyState(
            icon: switch (kind) {
              ActivityFeedKind.calls => Icons.call_outlined,
              ActivityFeedKind.sms => Icons.sms_outlined,
              ActivityFeedKind.messages => Icons.chat_bubble_outline,
            },
            title: switch (kind) {
              ActivityFeedKind.calls => 'No calls in this filter',
              ActivityFeedKind.sms => 'No SMS in this filter',
              ActivityFeedKind.messages => 'No chat alerts in this filter',
            },
            message: events.isEmpty
                ? switch (kind) {
                    ActivityFeedKind.calls =>
                      'Call history appears after call log consent is granted on the monitored device.',
                    ActivityFeedKind.sms =>
                      'Grant SMS permission on the monitored device to capture texts.',
                    ActivityFeedKind.messages =>
                      'Enable notification access on the monitored device for WhatsApp, Messenger, and similar apps.',
                  }
                : 'Try another filter to see matching activity.',
          )
        else
          ...filtered.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ActivityCard(
                kind: kind,
                event: event,
                onTap: () => widget.onOpen(event),
              ),
            ),
          ),
        if (kind == ActivityFeedKind.sms ||
            kind == ActivityFeedKind.messages) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: tokens.primarySoft,
            elevated: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Safety keyword watchlist',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      _keywordsLoading
                          ? '…'
                          : '${_keywords.length} mutual trigger${_keywords.length == 1 ? '' : 's'}',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: 'Manage',
                      icon: Icons.edit_outlined,
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      onPressed: () => _openKeywordManager(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_keywords.isEmpty && !_keywordsLoading)
                  Text(
                    'No keywords yet. Add mutual triggers with Manage.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _keywords
                        .map(
                          (chip) => Chip(
                            label: Text(
                              chip.chipLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            backgroundColor: tokens.surface,
                            side: BorderSide(color: tokens.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: tokens.surfaceContainerLow,
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reciprocal ledger entry',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Both people can audit this sync session on the mutual transparency ledger.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'View transparency ledger',
                icon: Icons.menu_book_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => AppNavigator.toNamed(AppRoutes.audit),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : tokens.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : tokens.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyMandateBanner extends StatelessWidget {
  const _PrivacyMandateBanner({required this.kind});

  final ActivityFeedKind kind;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final title = switch (kind) {
      ActivityFeedKind.calls => 'Mutual Voice Privacy',
      ActivityFeedKind.sms ||
      ActivityFeedKind.messages => 'Mutual Privacy Mandate',
    };
    final body = switch (kind) {
      ActivityFeedKind.calls =>
        'Spy Love records caller ID, timestamps, direction, and duration for mutual safety. Audio recording or live wiretapping is strictly blocked by protocol.',
      ActivityFeedKind.sms =>
        'Sender, timestamp, and consented preview sync for mutual safety. Sensitive codes can be redacted on-device.',
      ActivityFeedKind.messages =>
        'Only notification titles and previews from consented apps sync. Full chat archives are never captured.',
    };
    return AppCard(
      color: tokens.primarySoft,
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    if (kind == ActivityFeedKind.calls)
                      const StatusBadge(
                        label: 'Zero Eavesdropping',
                        tone: StatusTone.success,
                        showDot: false,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.kind,
    required this.event,
    required this.onTap,
  });

  final ActivityFeedKind kind;
  final DeviceEventModel event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final meta = EventPresentation.from(event);
    final payload = event.payload;
    final contact = event.contact;
    final direction = _ActivityFeedTabState._callDirection(event);
    final blocked = _ActivityFeedTabState._isBlocked(event);

    final (icon, tone) = switch (kind) {
      ActivityFeedKind.calls =>
        blocked
            ? (Icons.phone_disabled, StatusTone.danger)
            : switch (direction) {
                'incoming' => (Icons.call_received, StatusTone.success),
                'outgoing' => (Icons.call_made, StatusTone.info),
                'missed' => (Icons.call_missed, StatusTone.danger),
                _ => (Icons.call_outlined, StatusTone.neutral),
              },
      ActivityFeedKind.sms => (Icons.sms_outlined, StatusTone.info),
      ActivityFeedKind.messages => (Icons.chat_bubble_outline, StatusTone.info),
    };

    final duration =
        payload['duration']?.toString() ??
        payload['duration_seconds']?.toString();
    final number =
        payload['number']?.toString() ??
        payload['address']?.toString() ??
        payload['phone']?.toString() ??
        payload['from']?.toString();

    final callMeta = kind == ActivityFeedKind.calls
        ? [
            if (direction == 'incoming') 'Incoming',
            if (direction == 'outgoing') 'Outgoing',
            if (direction == 'missed') 'Missed',
            TimestampLabel.relative(event.eventTimestamp),
            if (duration != null && duration.isNotEmpty) '${duration}s',
          ].where((s) => s.isNotEmpty).join(' · ')
        : null;

    return AppCard(
      onTap: onTap,
      color: blocked ? tokens.dangerSoft.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContactAvatar(
                contact: contact,
                fallbackIcon: icon,
                danger: blocked,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.2),
                    ),
                    if (kind == ActivityFeedKind.calls && callMeta != null)
                      Text(
                        callMeta,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: tokens.secondaryText,
                          height: 1.35,
                        ),
                      )
                    else if (number != null &&
                        number.isNotEmpty &&
                        number != meta.title)
                      Text(
                        number,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
              if (kind != ActivityFeedKind.calls)
                TimestampLabel(event.eventTimestamp),
            ],
          ),
          if (kind != ActivityFeedKind.calls) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: tokens.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                meta.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (kind == ActivityFeedKind.calls) ...[
                if (contact.isKnown)
                  const StatusBadge(
                    label: 'Family',
                    tone: StatusTone.info,
                    showDot: false,
                  ),
                StatusBadge(
                  label: blocked ? 'Auto-Screened' : 'Completed',
                  tone: blocked ? StatusTone.danger : StatusTone.neutral,
                  showDot: false,
                  pulse: false,
                ),
                if (direction.isNotEmpty)
                  StatusBadge(
                    label: direction.toUpperCase(),
                    tone: blocked ? StatusTone.danger : StatusTone.info,
                    showDot: false,
                    pulse: false,
                  ),
              ] else ...[
                StatusBadge(
                  label: contact.isKnown
                      ? 'Safe verified contact'
                      : meta.sourceLabel,
                  tone: StatusTone.success,
                  showDot: false,
                  pulse: false,
                ),
                if (contact.isFlagged)
                  const StatusBadge(
                    label: 'Flagged',
                    tone: StatusTone.danger,
                    showDot: false,
                  ),
                if (contact.isRedacted)
                  const StatusBadge(
                    label: 'Redacted',
                    tone: StatusTone.neutral,
                    showDot: false,
                  )
                else
                  const StatusBadge(
                    label: 'Passed Keyword Audit',
                    tone: StatusTone.info,
                    showDot: false,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({
    required this.contact,
    required this.fallbackIcon,
    this.danger = false,
  });

  final ContactPayload contact;
  final IconData fallbackIcon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final bg = danger ? tokens.dangerSoft : tokens.primarySoft;
    final fg = danger ? tokens.revokeText : theme.colorScheme.primary;
    final photo = contact.contactPhotoUrl;
    final hasName = (contact.contactName ?? '').trim().isNotEmpty;

    Widget child;
    if (photo != null) {
      child = ClipOval(
        child: Image.network(
          photo,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (hasName) {
              return Center(
                child: Text(
                  contact.initials,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }
            return Icon(fallbackIcon, size: 20, color: fg);
          },
        ),
      );
    } else if (hasName) {
      child = Center(
        child: Text(
          contact.initials,
          style: theme.textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else {
      child = Icon(fallbackIcon, size: 20, color: fg);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

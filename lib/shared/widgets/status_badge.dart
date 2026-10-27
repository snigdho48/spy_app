import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';

enum StatusTone { success, warning, danger, info, neutral }

/// Consent / status chip with optional live pulse dot (Consent Horizon).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.showDot = true,
    this.pulse = false,
  });

  static String labelFor(String status) => _labelFor(status.toLowerCase());

  factory StatusBadge.device(String status) {
    final normalized = status.toLowerCase();
    return StatusBadge(
      label: _labelFor(normalized),
      pulse: normalized == 'active' || normalized == 'online',
      tone: switch (normalized) {
        'active' || 'online' || 'linked' || 'consented' => StatusTone.success,
        'pending' || 'pairing' || 'awaiting' => StatusTone.warning,
        'revoked' || 'disconnected' || 'error' => StatusTone.danger,
        'offline' || 'dormant' => StatusTone.neutral,
        _ => StatusTone.neutral,
      },
    );
  }

  factory StatusBadge.consent({required bool active}) {
    return StatusBadge(
      label: active ? 'Consented' : 'Awaiting Confirmation',
      tone: active ? StatusTone.success : StatusTone.warning,
      pulse: active,
    );
  }

  final String label;
  final StatusTone tone;
  final bool showDot;
  final bool pulse;

  static String _labelFor(String status) {
    return switch (status) {
      'active' => 'Active & Consented',
      'online' => 'Online',
      'pending' => 'Awaiting Re-consent',
      'revoked' => 'Revoked',
      'offline' => 'Off-Grid',
      'consented' => 'Consented',
      _ => status.isEmpty
          ? 'Unknown'
          : '${status[0].toUpperCase()}${status.substring(1)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (fg, bg, dot) = switch (tone) {
      StatusTone.success => (
          tokens.consentedLabel,
          tokens.successSoft,
          tokens.consented
        ),
      StatusTone.warning => (tokens.pending, tokens.warningSoft, tokens.pending),
      StatusTone.danger => (tokens.revokeText, tokens.dangerSoft, tokens.revoked),
      StatusTone.info => (
          Theme.of(context).colorScheme.primary,
          tokens.primarySoft,
          Theme.of(context).colorScheme.primary
        ),
      StatusTone.neutral => (tokens.dormant, tokens.dormantSoft, tokens.dormant),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              _StatusDot(color: dot, pulse: pulse),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                      height: 1.2,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (_controller == null) return dot;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller!),
      child: dot,
    );
  }
}

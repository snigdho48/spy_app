import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:intl/intl.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/app_page.dart';
import 'package:spy_love/app/core/widgets/app_states.dart';
import 'package:spy_love/app/core/widgets/transparency_ledger_tile.dart';
import 'package:spy_love/app/modules/audit/models/audit_log_model.dart';
import 'package:spy_love/app/modules/audit/repositories/audit_repository.dart';

class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key});

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  bool _loading = true;
  String _error = '';
  List<AuditLogModel> _logs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final result = await context.read<AuditRepository>().listLogs();
    if (!mounted) return;
    result.fold(
      (logs) => setState(() {
        _logs = logs;
        _loading = false;
      }),
      (error) => setState(() {
        _error = error;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Mutual audit log')),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: LoadingSkeleton(lines: 5),
            )
          : AppPage(
              onRefresh: _load,
              children: [
                const PageIntro(
                  title: 'Mutual audit log & ledger',
                  subtitle:
                      'Transparent record of pairing, consent changes, and who accessed what',
                ),
                if (_error.isNotEmpty)
                  ErrorState(message: _error, onRetry: _load)
                else if (_logs.isEmpty)
                  const EmptyState(
                    icon: Icons.history,
                    title: 'No activity yet',
                    message:
                        'Pair or manage a device to see mutual audit events here.',
                  )
                else
                  AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < _logs.length; i++) ...[
                          if (i > 0) const Divider(),
                          TransparencyLedgerTile(
                            scopeLabel: _logs[i].title,
                            consumerLabel: [
                              _logs[i].resourceType,
                              ..._logs[i].metadata.entries
                                  .take(2)
                                  .map((e) => '${e.key}: ${e.value}'),
                            ].where((s) => s.isNotEmpty).join(' · '),
                            timestampLabel: DateFormat(
                              'MMM d · HH:mm',
                            ).format(_logs[i].createdAt.toLocal()),
                            icon: Icons.history,
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'These records come from GET /audit/ — visible to the workspace for mutual accountability.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ),
    );
  }
}

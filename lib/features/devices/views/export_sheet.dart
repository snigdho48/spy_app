import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/controllers/device_detail_controller.dart';
import 'package:spy_love/features/devices/repositories/event_repository.dart';
import 'package:spy_love/shared/widgets/app_button.dart';

const _feedOptions = <(String, String)>[
  ('events', 'Events'),
  ('locations', 'Locations'),
  ('app_usage', 'App usage'),
  ('alerts', 'Alerts'),
  ('telemetry', 'Telemetry'),
];

Future<void> showExportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ExportSheet(),
  );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet();

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late DateTime _from;
  late DateTime _to;
  final Set<String> _feeds = {'events', 'locations', 'alerts'};
  String _format = 'csv';
  bool _busy = false;
  String? _error;
  String? _successPath;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = now;
    _from = now.subtract(const Duration(days: 7));
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: _to,
      initialDate: _from,
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _from,
      lastDate: DateTime.now(),
      initialDate: _to,
    );
    if (picked != null) {
      setState(
        () => _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
      );
    }
  }

  Future<void> _run() async {
    if (_feeds.isEmpty) {
      setState(() => _error = 'Pick at least one feed');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _successPath = null;
    });
    final device = context.read<DeviceDetailController>().device;
    final result = await context.read<EventRepository>().export(
      deviceId: device.id,
      from: _from,
      to: _to,
      feeds: _feeds.toList(),
      exportFormat: _format,
    );
    if (!mounted) return;
    await result.fold(
      (bytes) async {
        final path = await _saveAndShare(device.name, bytes);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _successPath = path;
        });
      },
      (error) async {
        setState(() {
          _busy = false;
          _error = error;
        });
      },
    );
  }

  Future<String> _saveAndShare(String deviceName, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final safe = deviceName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final ext = _format == 'pdf' ? 'pdf' : 'csv';
    final file = File('${dir.path}/spy_love_${safe}_$stamp.$ext');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Spy Love export · $deviceName',
        text: 'Consented device export ($ext) for $deviceName',
      ),
    );
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final fmt = DateFormat.yMMMd();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Export device data', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Downloads a consented feed snapshot for the selected range. '
            'CSV streams; PDF is a formatted report.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFrom,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text('From ${fmt.format(_from)}'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickTo,
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: Text('To ${fmt.format(_to)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Feeds', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final (id, label) in _feedOptions)
                FilterChip(
                  label: Text(label),
                  selected: _feeds.contains(id),
                  onSelected: _busy
                      ? null
                      : (v) => setState(() {
                          if (v) {
                            _feeds.add(id);
                          } else {
                            _feeds.remove(id);
                          }
                        }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Format', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'csv', label: Text('CSV'), icon: Icon(Icons.table_chart_outlined)),
              ButtonSegment(value: 'pdf', label: Text('PDF'), icon: Icon(Icons.picture_as_pdf_outlined)),
            ],
            selected: {_format},
            onSelectionChanged: _busy
                ? null
                : (s) => setState(() => _format = s.first),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_successPath != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Saved and shared. Temp file: $_successPath',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.consented,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _busy ? 'Exporting…' : 'Export & share',
            icon: Icons.ios_share_rounded,
            loading: _busy,
            onPressed: _busy ? null : _run,
          ),
        ],
      ),
    );
  }
}

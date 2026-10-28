import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/update/update_models.dart';
import 'package:spy_love/features/update/update_service.dart';

/// Consent-friendly update sheet. Nothing is downloaded until the user taps
/// "Update now". Shows progress during download and hands off to the system
/// installer. Safe to dismiss ("Later").
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info, required this.service});

  final AppReleaseInfo info;
  final UpdateService service;

  /// Checks for an update and, if one exists, shows the dialog. Returns true
  /// when a dialog was shown. Never throws.
  static Future<bool> maybeShow(
    BuildContext context,
    UpdateService service,
  ) async {
    final info = await service.checkForUpdate();
    if (info == null) return false;
    if (!context.mounted) return false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UpdateDialog(info: info, service: service),
    );
    return true;
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      final abis = await widget.service.supportedAbis();
      final url = widget.info.apkUrlForAbis(abis);
      if (url == null) {
        throw StateError('No matching APK in the latest release.');
      }
      await widget.service.downloadAndInstall(
        url,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Update failed. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update, color: tokens.primaryText),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Update available',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Version ${widget.info.version} (build ${widget.info.buildNumber}) is ready to install.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
          if (widget.info.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.info.notes.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.secondaryText),
            ),
          ],
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 8),
            Text(
              _progress > 0
                  ? 'Downloading ${(_progress * 100).toStringAsFixed(0)}%'
                  : 'Starting download…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              if (!_downloading)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Later'),
                  ),
                ),
              if (!_downloading) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _downloading ? null : _start,
                  child: Text(_downloading ? 'Installing…' : 'Update now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

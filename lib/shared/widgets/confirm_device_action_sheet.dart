import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';

/// Stitch "Live & Confirm Actions" — soft disconnect with optional permanent purge.
class ConfirmDeviceActionResult {
  const ConfirmDeviceActionResult({
    required this.confirmed,
    required this.purgeHistory,
  });

  final bool confirmed;
  final bool purgeHistory;
}

Future<ConfirmDeviceActionResult?> showDisconnectConfirmSheet(
  BuildContext context, {
  required String deviceName,
}) {
  return showGeneralDialog<ConfirmDeviceActionResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss disconnect confirm',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: animation,
              child: _DisconnectConfirmDialog(deviceName: deviceName),
            ),
          ),
        ),
      );
    },
  );
}

class _DisconnectConfirmDialog extends StatefulWidget {
  const _DisconnectConfirmDialog({required this.deviceName});

  final String deviceName;

  @override
  State<_DisconnectConfirmDialog> createState() => _DisconnectConfirmDialogState();
}

class _DisconnectConfirmDialogState extends State<_DisconnectConfirmDialog> {
  bool _purgeHistory = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetBorder),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tokens.dangerSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.link_off, color: tokens.revokeText, size: 28),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Disconnect ${widget.deviceName}?',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '● ACTION REVOKES LINK',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.revokeText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: tokens.surfaceContainerLow,
                    borderRadius: AppRadius.cardBorder,
                  ),
                  child: Text(
                    'This will immediately revoke access. The monitored person is notified that sharing has ended. Stored audit records remain archived unless you also purge history.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CheckboxListTile(
                  value: _purgeHistory,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setState(() => _purgeHistory = v ?? false),
                  title: Text(
                    'Also permanently delete all historical telemetry logs',
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    'Irreversible · Removes location history and telemetry caches',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tokens.revokeText,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.pop(
                    context,
                    ConfirmDeviceActionResult(
                      confirmed: true,
                      purgeHistory: _purgeHistory,
                    ),
                  ),
                  icon: const Icon(Icons.heart_broken_outlined),
                  label: const Text('Confirm Disconnect'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(
                    context,
                    const ConfirmDeviceActionResult(
                      confirmed: false,
                      purgeHistory: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_text_field.dart';
import 'package:spy_love/shared/widgets/consent_row.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/features/consent/controllers/pairing_controller.dart';
import 'package:spy_love/features/consent/models/consent_scope.dart';

class PairingCompleteView extends StatelessWidget {
  const PairingCompleteView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PairingController>();
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirm pairing & consent'),
            Text(
              '● CONSENTED LINK',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tokens.consented,
                  ),
            ),
          ],
        ),
      ),
      // Floating (overlay) Continue action instead of a docked bottom button.
      // Hidden while the camera scanner is open so it doesn't cover the frame.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: controller.useScanner
          ? null
          : _ContinueFab(controller: controller),
      body: controller.useScanner
          ? _ScannerPane(controller: controller)
          : _ApprovalForm(controller: controller),
    );
  }
}

class _ContinueFab extends StatelessWidget {
  const _ContinueFab({required this.controller});

  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.isPairingCodeValid &&
        controller.selectedScopes.isNotEmpty &&
        !controller.isLoading;
    return FloatingActionButton.extended(
      heroTag: 'pairing-continue',
      backgroundColor: enabled
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).disabledColor,
      onPressed: enabled ? () => controller.completePairing() : null,
      icon: controller.isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.verified_outlined),
      label: Text(controller.isLoading ? 'Sending…' : 'Confirm & continue'),
    );
  }
}

class _ScannerPane extends StatefulWidget {
  const _ScannerPane({required this.controller});

  final PairingController controller;

  @override
  State<_ScannerPane> createState() => _ScannerPaneState();
}

class _ScannerPaneState extends State<_ScannerPane> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                onDetect: (capture) {
                  if (_handled) return;
                  for (final barcode in capture.barcodes) {
                    final raw = barcode.rawValue;
                    if (raw == null || raw.isEmpty) continue;
                    _handled = true;
                    // Auto-fills the code and auto-continues when valid.
                    widget.controller.applyScannedPayload(raw);
                    break;
                  }
                },
              ),
              // Framing + scan hint overlay.
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Point the camera at the monitored phone\'s pairing QR. '
                    'The code fills in and pairing continues automatically.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(
            label: 'Enter code manually',
            variant: AppButtonVariant.secondary,
            onPressed: () => widget.controller.setUseScanner(false),
          ),
        ),
      ],
    );
  }
}

class _ApprovalForm extends StatelessWidget {
  const _ApprovalForm({required this.controller});

  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return ListView(
      // Extra bottom padding so the floating Continue button never covers the
      // last controls.
      padding: context.pagePadding.add(const EdgeInsets.only(bottom: 96)),
      children: [
        AppCard(
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
                    Text('Define mutual scope boundary', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Select telemetry channels to request. The monitored member must approve this exact list.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: controller.codeController,
          label: 'Pairing code',
          hint: 'ABC-123',
          textCapitalization: TextCapitalization.characters,
          onChanged: controller.setPairingCodeInput,
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Or scan QR code',
          icon: Icons.qr_code_scanner,
          variant: AppButtonVariant.secondary,
          onPressed: () => controller.setUseScanner(true),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text('Scopes requested', style: theme.textTheme.titleLarge),
            ),
            StatusBadge(
              label: '${controller.selectedScopes.length}/${ConsentScope.all.length}',
              tone: StatusTone.info,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            TextButton(
              onPressed: () {
                for (final s in ConsentScope.all) {
                  controller.toggleScope(s.id, true);
                }
              },
              child: const Text('Select all'),
            ),
            TextButton(
              onPressed: () {
                for (final s in ConsentScope.all) {
                  controller.toggleScope(s.id, false);
                }
              },
              child: const Text('Clear all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < ConsentScope.all.length; i++) ...[
                if (i > 0) const Divider(),
                ConsentRow(
                  title: ConsentScope.all[i].label,
                  subtitle: ConsentScope.all[i].description,
                  enabled: controller.selectedScopes.contains(
                    ConsentScope.all[i].id,
                  ),
                  onChanged: (checked) =>
                      controller.toggleScope(ConsentScope.all[i].id, checked),
                  statusLabel:
                      controller.selectedScopes.contains(ConsentScope.all[i].id)
                      ? 'Consented'
                      : 'Off',
                  statusTone:
                      controller.selectedScopes.contains(ConsentScope.all[i].id)
                      ? StatusTone.success
                      : StatusTone.neutral,
                ),
              ],
            ],
          ),
        ),
        if (controller.errorMessage.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            controller.errorMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Cancel & abort pairing',
          icon: Icons.close,
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_button.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/app_text_field.dart';
import 'package:spy_love/app/core/widgets/consent_row.dart';
import 'package:spy_love/app/core/widgets/status_badge.dart';
import 'package:spy_love/app/modules/pairing/controllers/pairing_controller.dart';
import 'package:spy_love/app/modules/pairing/models/consent_scope.dart';

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
      body: controller.useScanner
          ? _ScannerPane(controller: controller)
          : _ApprovalForm(controller: controller),
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
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final raw = barcode.rawValue;
                if (raw == null || raw.isEmpty) continue;
                _handled = true;
                widget.controller.applyScannedPayload(raw);
                break;
              }
            },
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
      padding: context.pagePadding,
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
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Confirm & send consent agreement',
          icon: Icons.send_outlined,
          loading: controller.isLoading,
          onPressed: controller.isLoading
              ? null
              : () => controller.completePairing(),
        ),
        const SizedBox(height: AppSpacing.sm),
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

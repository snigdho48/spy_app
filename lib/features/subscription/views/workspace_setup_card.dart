import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/theme/app_colors.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_text_field.dart';
import 'package:spy_love/features/subscription/controllers/subscription_controller.dart';

class WorkspaceSetupCard extends StatelessWidget {
  const WorkspaceSetupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionController>(
      builder: (context, subscription, _) {
      if (!subscription.needsWorkspace) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppCard(
          color: context.tokens.warningSoft,
          borderColor: AppColors.warning.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Workspace required', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Create a workspace before pairing devices or loading monitoring data. A Free plan is applied automatically.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.tokens.secondaryText,
                    ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Create workspace',
                icon: Icons.business_outlined,
                onPressed: () => _showDialog(context),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final nameController = TextEditingController(text: 'My Workspace');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create workspace'),
        content: Form(
          key: formKey,
          child: AppTextField(
            controller: nameController,
            label: 'Organization / workspace name',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await context.read<SubscriptionController>().createWorkspace(nameController.text.trim());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    nameController.dispose();
  }
}

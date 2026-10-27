import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/core/theme/app_colors.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_button.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/app_page.dart';
import 'package:spy_love/app/core/widgets/app_states.dart';
import 'package:spy_love/app/core/widgets/status_badge.dart';
import 'package:spy_love/app/modules/subscription/controllers/subscription_controller.dart';
import 'package:spy_love/app/modules/subscription/models/subscription_models.dart';

class SubscriptionPlansView extends StatelessWidget {
  const SubscriptionPlansView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SubscriptionController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription plans')),
      body: controller.isLoading && controller.plans.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: LoadingSkeleton(lines: 3),
            )
          : AppPage(
              onRefresh: () async {
                await controller.loadPlans();
                await controller.loadCurrent();
              },
              children: [
                const PageIntro(
                  title: 'Subscription plans',
                  subtitle:
                      'Choose the level that fits your family or team workspace',
                ),
                if (controller.current != null) ...[
                  _CurrentPlanCard(info: controller.current!),
                  const SizedBox(height: 24),
                ],
                if (controller.errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ErrorState(
                      message: controller.errorMessage,
                      onRetry: controller.loadPlans,
                    ),
                  ),
                ...controller.plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanCard(plan: plan),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.tokens.primarySoft,
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT PLAN',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            info.planName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Up to ${info.maxDevices} active devices',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          StatusBadge(label: 'Current', tone: StatusTone.success),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SubscriptionController>();
    final isCurrent = controller.current?.planCode == plan.code;
    final price = plan.priceMonthlyUsd == 0
        ? 'Free'
        : '\$${plan.priceMonthlyUsd.toStringAsFixed(0)} / month';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(price, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Up to ${plan.maxDevices} devices',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          ...plan.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: context.tokens.consented),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(feature)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isCurrent)
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                label: 'Current plan',
                tone: StatusTone.success,
                pulse: true,
              ),
            )
          else
            AppButton(
              label: plan.priceMonthlyUsd == 0 ? 'Switch to Free' : 'Subscribe',
              onPressed: () => controller.subscribe(plan.code),
            ),
        ],
      ),
    );
  }
}

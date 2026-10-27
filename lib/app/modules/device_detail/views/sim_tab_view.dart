import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/core/navigation/app_navigator.dart';
import 'package:spy_love/app/core/theme/app_colors.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/app_states.dart';
import 'package:spy_love/app/core/widgets/event_list_tile.dart';
import 'package:spy_love/app/core/widgets/status_badge.dart';
import 'package:spy_love/app/core/widgets/timestamp_label.dart';
import 'package:spy_love/app/modules/device_detail/controllers/device_detail_controller.dart';
import 'package:spy_love/app/modules/device_detail/models/device_event_model.dart';
import 'package:spy_love/app/routes/app_routes.dart';

class SimTabView extends StatelessWidget {
  const SimTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceDetailController>();
    if (controller.isLoadingEvents &&
        controller.currentSims.isEmpty &&
        controller.simHistory.isEmpty) {
      return const Padding(padding: EdgeInsets.all(24), child: LoadingSkeleton(lines: 4));
    }

      return RefreshIndicator(
        onRefresh: controller.refreshSimEvents,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            AppCard(
              color: context.tokens.primarySoft,
              elevated: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sim_card_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'SIM Security',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const StatusBadge(
                              label: 'Swap Alerts On',
                              tone: StatusTone.success,
                              showDot: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Insert and remove events sync with phone consent. Carrier and number stay visible to both sides of the link.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: context.tokens.secondaryText,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Active SIM', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (controller.currentSims.isEmpty)
              const EmptyState(
                icon: Icons.sim_card_outlined,
                title: 'No SIM data yet',
                message: 'Grant phone/SIM consent on the monitored device to see the inserted number.',
              )
            else
              ...controller.currentSims.map((sim) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _currentSimCard(context, sim),
                  )),
            const SizedBox(height: 12),
            Text('Insert / remove history', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (controller.simHistory.isEmpty)
              const EmptyState(
                title: 'No SIM changes yet',
                message: 'Insert or remove a card on the monitored phone to record history.',
              )
            else
              ...controller.simHistory.map((event) => _historyTile(controller, event)),
          ],
        ),
      );
  }

  Widget _currentSimCard(BuildContext context, Map<String, dynamic> sim) {
    final tokens = context.tokens;
    final slot = sim['slot'];
    final number = _displayNumber(sim['phone_number']?.toString());
    final carrier = sim['carrier']?.toString().trim();
    final displayName = sim['display_name']?.toString().trim();
    final updatedAt = sim['updated_at'] as DateTime?;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sim_card, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(number, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  [
                    if (displayName?.isNotEmpty == true) displayName!,
                    if (carrier?.isNotEmpty == true) carrier!,
                    if (slot != null) 'Slot $slot',
                    if (updatedAt != null) TimestampLabel.format(updatedAt),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(DeviceDetailController controller, DeviceEventModel event) {
    final p = event.payload;
    final number = _displayNumber(p['phone_number']?.toString());
    final slot = p['slot'];
    final carrier = p['carrier']?.toString().trim();
    final isInserted = event.eventType == 'sim.inserted';

    return EventListTile(
      title: '${isInserted ? 'Inserted' : 'Removed'} · $number',
      preview: [if (carrier?.isNotEmpty == true) carrier!, if (slot != null) 'Slot $slot'].join(' · '),
      timestamp: event.eventTimestamp,
      icon: isInserted ? Icons.sim_card_download : Icons.sim_card_alert,
      leadingColor: isInserted ? AppColors.success : AppColors.warning,
      onTap: () => AppNavigator.toNamed(
        AppRoutes.eventDetail,
        arguments: {
          'event': event,
          'deviceName': controller.device.name,
          'consentActive': controller.consent != null,
        },
      ),
    );
  }

  String _displayNumber(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? 'Number unavailable' : value;
  }
}

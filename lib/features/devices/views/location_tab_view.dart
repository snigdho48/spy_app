import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/routes.dart';
import 'package:spy_love/core/theme/app_colors.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/devices/controllers/device_detail_controller.dart';
import 'package:spy_love/features/devices/models/location_point.dart';
import 'package:spy_love/features/devices/models/safe_zone_model.dart';
import 'package:spy_love/features/devices/views/geofence_editor_sheet.dart';
import 'package:spy_love/features/devices/views/location_map_fullscreen_view.dart';
import 'package:spy_love/features/devices/widgets/location_history_map.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_states.dart';
import 'package:spy_love/shared/widgets/section_header.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';
import 'package:spy_love/shared/widgets/timestamp_label.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationTabView extends StatelessWidget {
  const LocationTabView({super.key});

  bool _canEdit(BuildContext context) {
    final role = context.read<AuthController>().user?.role?.toUpperCase();
    return role != 'VIEWER';
  }

  void _openFullscreen(
    BuildContext context,
    DeviceDetailController controller,
  ) {
    final points = controller.filteredLocations;
    if (points.isEmpty) return;
    Navigator.of(context).pushNamed(
      AppRoutes.locationMapFullscreen,
      arguments: LocationMapFullscreenArgs(
        points: List<LocationPoint>.from(points),
        deviceName: controller.device.name,
      ),
    );
  }

  Future<void> _addOrEdit(
    BuildContext context,
    DeviceDetailController controller, {
    SafeZoneModel? existing,
    LatLng? center,
  }) async {
    if (!_canEdit(context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viewers can browse safe zones but cannot edit them'),
        ),
      );
      return;
    }
    final draft = await showGeofenceEditorSheet(
      context,
      existing: existing,
      initialCenter: center ??
          (controller.latestLocation != null
              ? LatLng(
                  controller.latestLocation!.lat,
                  controller.latestLocation!.lng,
                )
              : null),
    );
    if (draft == null || !context.mounted) return;

    final error = existing == null
        ? await controller.createSafeZone(
            name: draft.name,
            lat: draft.lat,
            lng: draft.lng,
            radiusM: draft.radiusM,
            address: draft.address,
            enabled: draft.enabled,
          )
        : await controller.updateSafeZone(
            id: existing.id,
            name: draft.name,
            lat: draft.lat,
            lng: draft.lng,
            radiusM: draft.radiusM,
            address: draft.address,
            enabled: draft.enabled,
          );
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    DeviceDetailController controller,
    SafeZoneModel zone,
  ) async {
    if (!_canEdit(context)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete safe zone?'),
        content: Text(
          'Remove "${zone.name}"? Enter/exit alerts for this zone will stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error = await controller.deleteSafeZone(zone.id);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceDetailController>();
    if (controller.isLoadingEvents && controller.locations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: LoadingSkeleton(lines: 4),
      );
    }

    final points = controller.filteredLocations;
    final latest = controller.latestLocation;
    final tokens = context.tokens;
    final zoneLabel = latest?.zoneName ?? latest?.placeName;
    final canEdit = _canEdit(context);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          controller.refreshLocations(),
          controller.refreshSafeZones(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          if (latest != null)
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tokens.successSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latest.displayLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        TimestampLabel(latest.timestamp),
                        Text(
                          '${latest.lat.toStringAsFixed(5)}, ${latest.lng.toStringAsFixed(5)}'
                          '${latest.accuracyM == null ? '' : ' · ±${latest.accuracyM!.toStringAsFixed(0)} m'}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: tokens.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (zoneLabel != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tokens.successSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school_outlined, color: tokens.consented),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zoneLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          latest?.zoneName != null
                              ? 'Inside · from last location ping'
                              : 'Place label from last location ping',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: tokens.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  const StatusBadge(
                    label: 'Inside',
                    tone: StatusTone.success,
                    showDot: false,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: 'Open Directions',
            icon: Icons.directions_outlined,
            onPressed: latest == null ? null : () => _openMaps(latest),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: LocationDateFilter.values.map((filter) {
              final selected = controller.locationFilter == filter;
              return FilterChip(
                label: Text(filter.label),
                selected: selected,
                onSelected: (_) => controller.setLocationFilter(filter),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _MapPreviewCard(
            points: points,
            controller: controller,
            canEdit: canEdit,
            onExpand: () => _openFullscreen(context, controller),
            onLongPress: canEdit
                ? (point) => _addOrEdit(context, controller, center: point)
                : null,
          ),
          const SizedBox(height: 20),
          _SafeZonesSection(
            controller: controller,
            canEdit: canEdit,
            onAdd: () => _addOrEdit(context, controller),
            onEdit: (zone) => _addOrEdit(context, controller, existing: zone),
            onDelete: (zone) => _delete(context, controller, zone),
            onToggle: (zone, enabled) async {
              final error = await controller.updateSafeZone(
                id: zone.id,
                enabled: enabled,
              );
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Location history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (points.isNotEmpty)
                Text(
                  '${points.length} point${points.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (points.isEmpty)
            const EmptyState(
              title: 'No points in this range',
              message:
                  'Try another date filter after the device has uploaded locations.',
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < points.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: tokens.border),
                    _LocationHistoryTile(
                      point: points[i],
                      isLatest: i == 0,
                      onTap: () {
                        controller.mapController.move(
                          LatLng(points[i].lat, points[i].lng),
                          16,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openMaps(LocationPoint point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${point.lat},${point.lng}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SafeZonesSection extends StatelessWidget {
  const _SafeZonesSection({
    required this.controller,
    required this.canEdit,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final DeviceDetailController controller;
  final bool canEdit;
  final VoidCallback onAdd;
  final void Function(SafeZoneModel) onEdit;
  final void Function(SafeZoneModel) onDelete;
  final void Function(SafeZoneModel, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final zones = controller.safeZones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Safe zones',
          subtitle: canEdit
              ? 'Long-press the map to drop a centre, or add below'
              : 'View only — ask a monitor to edit',
          action: canEdit
              ? IconButton(
                  tooltip: 'Add safe zone',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_location_alt_outlined),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (controller.isLoadingSafeZones && zones.isEmpty)
          const LoadingSkeleton(lines: 2)
        else if (zones.isEmpty)
          AppCard(
            child: Text(
              canEdit
                  ? 'No safe zones yet. Long-press the map or tap + to create one.'
                  : 'No safe zones configured for this device.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < zones.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: tokens.border),
                  Semantics(
                    label:
                        'Safe zone ${zones[i].name}, ${zones[i].radiusM} meters, '
                        '${zones[i].enabled ? "enabled" : "disabled"}',
                    child: ListTile(
                      leading: Icon(
                        Icons.shield_outlined,
                        color: zones[i].enabled
                            ? Theme.of(context).colorScheme.primary
                            : tokens.dormant,
                      ),
                      title: Text(zones[i].name),
                      subtitle: Text(
                        [
                          if (zones[i].address.isNotEmpty) zones[i].address,
                          '${zones[i].radiusM} m',
                        ].join(' · '),
                      ),
                      trailing: canEdit
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: zones[i].enabled,
                                  onChanged: (v) => onToggle(zones[i], v),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') onEdit(zones[i]);
                                    if (value == 'delete') onDelete(zones[i]);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : StatusBadge(
                              label: zones[i].enabled ? 'On' : 'Off',
                              tone: zones[i].enabled
                                  ? StatusTone.success
                                  : StatusTone.neutral,
                              showDot: false,
                            ),
                      onTap: canEdit ? () => onEdit(zones[i]) : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (canEdit) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Add safe zone',
            icon: Icons.add,
            variant: AppButtonVariant.secondary,
            onPressed: onAdd,
          ),
        ],
      ],
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard({
    required this.points,
    required this.controller,
    required this.onExpand,
    required this.canEdit,
    this.onLongPress,
  });

  final List<LocationPoint> points;
  final DeviceDetailController controller;
  final VoidCallback onExpand;
  final bool canEdit;
  final void Function(LatLng point)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
            child: Row(
              children: [
                Icon(Icons.map_outlined, size: 18, color: tokens.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    canEdit
                        ? 'Map preview · long-press to drop a zone'
                        : 'Map preview',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: points.isEmpty ? null : onExpand,
                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                  label: const Text('Full screen'),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.card),
            ),
            child: SizedBox(
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LocationHistoryMap(
                    points: points,
                    mapController: controller.mapController,
                    interactive: canEdit,
                    safeZones: controller.safeZones,
                    onTap: points.isEmpty ? null : onExpand,
                    onLongPress: onLongPress,
                  ),
                  if (points.isNotEmpty)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Material(
                        color: tokens.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        child: Semantics(
                          button: true,
                          label: 'Expand location map',
                          child: InkWell(
                            onTap: onExpand,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.open_in_full_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('Expand'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationHistoryTile extends StatelessWidget {
  const _LocationHistoryTile({
    required this.point,
    required this.isLatest,
    required this.onTap,
  });

  final LocationPoint point;
  final bool isLatest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final subtitle = [
      if (point.address != null &&
          point.address!.trim().isNotEmpty &&
          point.address != point.displayLabel)
        point.address!.trim(),
      '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
      if (point.accuracyM != null) '±${point.accuracyM!.toStringAsFixed(0)} m',
    ].join(' · ');

    return Semantics(
      button: true,
      label:
          '${isLatest ? "Latest location" : "Location history point"}: ${point.displayLabel}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: isLatest
                            ? AppColors.danger
                            : Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isLatest
                                        ? AppColors.danger
                                        : Theme.of(context).colorScheme.primary)
                                    .withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              point.displayLabel,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLatest)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: StatusBadge(
                                label: 'Latest',
                                tone: StatusTone.info,
                                showDot: false,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TimestampLabel(point.timestamp),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: tokens.secondaryText,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:spy_love/app/core/theme/app_colors.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_button.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/app_states.dart';
import 'package:spy_love/app/core/widgets/event_list_tile.dart';
import 'package:spy_love/app/core/widgets/status_badge.dart';
import 'package:spy_love/app/core/widgets/timestamp_label.dart';
import 'package:spy_love/app/modules/device_detail/controllers/device_detail_controller.dart';
import 'package:spy_love/app/modules/device_detail/models/location_point.dart';
import 'package:spy_love/app/modules/device_detail/utils/location_map_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationTabView extends StatelessWidget {
  const LocationTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceDetailController>();
    if (controller.isLoadingEvents && controller.locations.isEmpty) {
        return const Padding(padding: EdgeInsets.all(24), child: LoadingSkeleton(lines: 4));
      }

      final points = controller.filteredLocations;
      final latest = controller.latestLocation;
      final path = toLatLngs(points.reversed.toList());
      final tokens = context.tokens;

      final zoneLabel = latest?.zoneName ?? latest?.placeName;
      return RefreshIndicator(
        onRefresh: controller.refreshLocations,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            if (latest != null)
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Latest location', style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            latest.displayLabel,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                          ),
                          if (zoneLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: StatusBadge(
                                label: latest.zoneName != null
                                    ? 'Inside Safe Zone'
                                    : zoneLabel,
                                tone: StatusTone.success,
                                showDot: false,
                              ),
                            ),
                          if (latest.placeName != null || latest.zoneName != null)
                            Text(
                              '${latest.lat.toStringAsFixed(5)}, ${latest.lng.toStringAsFixed(5)}',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: tokens.secondaryText,
                                  ),
                            ),
                          TimestampLabel(latest.timestamp),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Open in Google Maps',
                      onPressed: () => _openMaps(latest),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            AppCard(
              color: tokens.primarySoft,
              elevated: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.visibility_outlined, color: tokens.consented),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Mutual Transparency',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const StatusBadge(
                              label: 'Active',
                              tone: StatusTone.success,
                              showDot: true,
                              pulse: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The monitored person receives an instant banner whenever live location is viewed or pinned by family members.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: tokens.secondaryText,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Active Geofence Zones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusBadge(
                  label: zoneLabel == null ? '0' : '1+',
                  tone: StatusTone.info,
                  showDot: false,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (zoneLabel != null)
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
                          Text(zoneLabel, style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            latest?.zoneName != null
                                ? 'Inside · from last location ping'
                                : 'Place label from last location ping',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: tokens.secondaryText,
                                ),
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
              )
            else
              Text(
                'Safe zones are managed under Account. Zone enter/exit events appear in the history below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.secondaryText,
                    ),
              ),
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
            ClipRRect(
              borderRadius: AppRadius.cardBorder,
              child: SizedBox(
                height: 280,
                child: points.isEmpty
                    ? ColoredBox(
                        color: tokens.input,
                        child: const EmptyState(
                          icon: Icons.map_outlined,
                          title: 'No location data yet',
                          message: 'Grant location on the monitored device to see live position and history.',
                        ),
                      )
                    : FlutterMap(
                        mapController: controller.mapController,
                        options: MapOptions(
                          initialCenter: centerForPoints(points),
                          initialZoom: 14,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'org.hmg.spy_love',
                          ),
                          if (path.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: path,
                                  color: Theme.of(context).colorScheme.primary,
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (latest != null)
                                Marker(
                                  point: LatLng(latest.lat, latest.lng),
                                  width: 44,
                                  height: 44,
                                  child: const Icon(Icons.location_on, color: AppColors.danger, size: 40),
                                ),
                              ...points.skip(1).map(
                                    (p) => Marker(
                                      point: LatLng(p.lat, p.lng),
                                      width: 14,
                                      height: 14,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1),
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Location history', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (points.isEmpty)
              const EmptyState(
                title: 'No points in this range',
                message: 'Try another date filter after the device has uploaded locations.',
              )
            else
              ...points.map(
                (point) => EventListTile(
                  title: '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
                  preview: point.accuracyM == null ? 'Tap to focus map' : '±${point.accuracyM!.toStringAsFixed(0)} m',
                  timestamp: point.timestamp,
                  icon: Icons.place_outlined,
                  onTap: () => controller.mapController.move(LatLng(point.lat, point.lng), 16),
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

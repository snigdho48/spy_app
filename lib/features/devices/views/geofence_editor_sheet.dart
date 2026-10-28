import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:spy_love/core/theme/app_colors.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/models/safe_zone_model.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_text_field.dart';

/// Result returned by [showGeofenceEditorSheet] for create/edit.
class GeofenceDraft {
  const GeofenceDraft({
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.address,
    required this.enabled,
  });

  final String name;
  final double lat;
  final double lng;
  final int radiusM;
  final String address;
  final bool enabled;
}

/// Modal editor: tap/long-press the map to place the centre, drag the radius
/// slider, and fill name/address. Returns a [GeofenceDraft] on save, or null
/// when cancelled.
Future<GeofenceDraft?> showGeofenceEditorSheet(
  BuildContext context, {
  SafeZoneModel? existing,
  LatLng? initialCenter,
  String? suggestedName,
}) {
  return showModalBottomSheet<GeofenceDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _GeofenceEditorSheet(
      existing: existing,
      initialCenter: initialCenter,
      suggestedName: suggestedName,
    ),
  );
}

class _GeofenceEditorSheet extends StatefulWidget {
  const _GeofenceEditorSheet({
    this.existing,
    this.initialCenter,
    this.suggestedName,
  });

  final SafeZoneModel? existing;
  final LatLng? initialCenter;
  final String? suggestedName;

  @override
  State<_GeofenceEditorSheet> createState() => _GeofenceEditorSheetState();
}

class _GeofenceEditorSheetState extends State<_GeofenceEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final MapController _map;
  late LatLng _center;
  late double _radiusM;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(
      text: e?.name ?? widget.suggestedName ?? '',
    );
    _address = TextEditingController(text: e?.address ?? '');
    _center = e != null
        ? LatLng(e.lat, e.lng)
        : (widget.initialCenter ?? const LatLng(23.8103, 90.4125));
    _radiusM = (e?.radiusM ?? 150).toDouble();
    _enabled = e?.enabled ?? true;
    _map = MapController();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _map.dispose();
    super.dispose();
  }

  void _place(LatLng point) => setState(() => _center = point);

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give this safe zone a name')),
      );
      return;
    }
    Navigator.of(context).pop(
      GeofenceDraft(
        name: name,
        lat: _center.latitude,
        lng: _center.longitude,
        radiusM: _radiusM.round().clamp(30, 5000),
        address: _address.text.trim(),
        enabled: _enabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final editing = widget.existing != null;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit safe zone' : 'Add safe zone',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tap the map to place the centre. Drag the slider to set radius. '
              'Enter/exit alerts fire when the consented device crosses the boundary.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _name,
              label: 'Name',
              hint: 'Home, School, Work…',
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _address,
              label: 'Address (optional)',
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.cardBorder,
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    onTap: (_, point) => _place(point),
                    onLongPress: (_, point) => _place(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'org.hmg.spy_love',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _center,
                          radius: _radiusM,
                          useRadiusInMeter: true,
                          color: AppColors.primary.withValues(alpha: 0.18),
                          borderColor: AppColors.primary,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _center,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.place_rounded,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text('Radius', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  '${_radiusM.round()} m',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Semantics(
              label: 'Safe zone radius, ${_radiusM.round()} meters',
              child: Slider(
                value: _radiusM,
                min: 30,
                max: 2000,
                divisions: 197,
                label: '${_radiusM.round()} m',
                onChanged: (v) => setState(() => _radiusM = v),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              subtitle: Text(
                'Enter/exit alerts fire only while enabled',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            AppButton(
              label: editing ? 'Save changes' : 'Create zone',
              icon: editing ? Icons.check : Icons.add_location_alt_outlined,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

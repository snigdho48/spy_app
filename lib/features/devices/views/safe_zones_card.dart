import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/features/devices/controllers/dashboard_controller.dart';
import 'package:spy_love/features/devices/models/safe_zone_model.dart';
import 'package:spy_love/features/devices/repositories/safe_zone_repository.dart';

/// Minimal safe-zone list + create/delete for workspace monitors.
class SafeZonesCard extends StatefulWidget {
  const SafeZonesCard({super.key});

  @override
  State<SafeZonesCard> createState() => _SafeZonesCardState();
}

class _SafeZonesCardState extends State<SafeZonesCard> {
  List<SafeZoneModel> _zones = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await context.read<SafeZoneRepository>().list();
    if (!mounted) return;
    result.fold(
      (zones) => setState(() {
        _zones = zones;
        _loading = false;
      }),
      (error) => setState(() {
        _error = error;
        _loading = false;
        _zones = const [];
      }),
    );
  }

  Future<void> _showCreateSheet() async {
    final dashboard = context.read<DashboardController>();
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '23.8103');
    final lngCtrl = TextEditingController(text: '90.4125');
    final radiusCtrl = TextEditingController(text: '100');
    String? deviceId =
        dashboard.devices.isEmpty ? null : dashboard.devices.first.id;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.md,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add safe zone', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Lat'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: lngCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Lng'),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: radiusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Radius (meters)',
                    ),
                  ),
                  if (dashboard.devices.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String?>(
                      // ignore: deprecated_member_use
                      value: deviceId,
                      decoration: const InputDecoration(
                        labelText: 'Device scope',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Entire workspace'),
                        ),
                        ...dashboard.devices.map(
                          (d) => DropdownMenuItem<String?>(
                            value: d.id,
                            child: Text(d.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setSheet(() => deviceId = v),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Create zone',
                    icon: Icons.add_location_alt_outlined,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (created != true || !mounted) return;
    final lat = double.tryParse(latCtrl.text.trim());
    final lng = double.tryParse(lngCtrl.text.trim());
    final radius = int.tryParse(radiusCtrl.text.trim()) ?? 100;
    final name = nameCtrl.text.trim();
    if (name.isEmpty || lat == null || lng == null) return;

    setState(() => _busy = true);
    final result = await context.read<SafeZoneRepository>().create(
          name: name,
          lat: lat,
          lng: lng,
          radiusM: radius,
          address: addressCtrl.text.trim(),
          deviceId: deviceId,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold((_) => _load(), (_) {});
  }

  Future<void> _delete(SafeZoneModel zone) async {
    setState(() => _busy = true);
    final result = await context.read<SafeZoneRepository>().delete(zone.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold((_) => _load(), (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Safe zones', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Named places for geofence enter/exit. No reverse geocoding — labels come from zones you create.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: LinearProgressIndicator(),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else if (_zones.isEmpty)
                Text(
                  'No safe zones yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                )
              else
                ..._zones.map((zone) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(zone.label),
                    subtitle: Text(
                      [
                        if (zone.address.isNotEmpty) zone.address,
                        '${zone.radiusM}m · ${zone.lat.toStringAsFixed(3)}, ${zone.lng.toStringAsFixed(3)}',
                      ].join(' · '),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy ? null : () => _delete(zone),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Add safe zone',
                icon: Icons.add,
                variant: AppButtonVariant.secondary,
                onPressed: _busy || _loading ? null : _showCreateSheet,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

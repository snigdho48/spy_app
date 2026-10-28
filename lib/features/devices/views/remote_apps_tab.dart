import 'package:flutter/material.dart';
import 'package:spy_love/app/routes.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';
import 'package:spy_love/shared/widgets/app_states.dart';

/// Monitor-side apps view. Shows the REMOTE device's installed-app inventory
/// (GET /events/app-inventory/latest/, consent maps to `app_usage`) and its
/// recent app-usage snapshot. The local on-device "all apps" list lives in
/// [InstalledAppsView], reachable from the button below.
class RemoteAppsTab extends StatefulWidget {
  const RemoteAppsTab({
    super.key,
    required this.inventory,
    required this.usageEvents,
    required this.isLoading,
  });

  /// Latest app_inventory.snapshot payload ({apps, app_count, include_system}).
  final Map<String, dynamic>? inventory;
  final List<DeviceEventModel> usageEvents;
  final bool isLoading;

  @override
  State<RemoteAppsTab> createState() => _RemoteAppsTabState();
}

enum _AppsMode { installed, usage }

class _RemoteAppsTabState extends State<RemoteAppsTab> {
  _AppsMode _mode = _AppsMode.installed;
  String _query = '';

  List<Map<String, dynamic>> get _inventoryApps {
    final raw = widget.inventory?['apps'];
    if (raw is! List) return const [];
    final apps = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? apps
        : apps.where((a) {
            final name = (a['name'] ?? '').toString().toLowerCase();
            final pkg = (a['package'] ?? '').toString().toLowerCase();
            return name.contains(q) || pkg.contains(q);
          }).toList();
    filtered.sort(
      (a, b) =>
          (a['name'] ?? a['package'] ?? '').toString().toLowerCase().compareTo(
            (b['name'] ?? b['package'] ?? '').toString().toLowerCase(),
          ),
    );
    return filtered;
  }

  List<Map<String, dynamic>> get _usageApps {
    final snapshot = widget.usageEvents.isEmpty
        ? null
        : widget.usageEvents.first;
    final raw = snapshot?.payload['apps'];
    if (raw is! List) return const [];
    final apps = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    apps.sort((a, b) {
      final av = _int(a['foreground_ms'] ?? a['total_time_foreground_ms']);
      final bv = _int(b['foreground_ms'] ?? b['total_time_foreground_ms']);
      return bv.compareTo(av);
    });
    return apps;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    if (widget.isLoading &&
        widget.inventory == null &&
        widget.usageEvents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SegmentedButton<_AppsMode>(
            segments: const [
              ButtonSegment(
                value: _AppsMode.installed,
                label: Text('Installed'),
                icon: Icon(Icons.apps),
              ),
              ButtonSegment(
                value: _AppsMode.usage,
                label: Text('Usage'),
                icon: Icon(Icons.timelapse),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        if (_mode == _AppsMode.installed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search installed apps',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.phone_android),
            label: const Text('View all installed apps (this device)'),
            onPressed: () => AppNavigator.toNamed(AppRoutes.installedApps),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _mode == _AppsMode.installed
              ? _buildInstalled(theme, tokens)
              : _buildUsage(theme, tokens),
        ),
      ],
    );
  }

  Widget _buildInstalled(ThemeData theme, AppTokens tokens) {
    final apps = _inventoryApps;
    if (apps.isEmpty) {
      return const EmptyState(
        title: 'No remote inventory yet',
        message:
            'The monitored device has not uploaded an installed-app inventory. '
            'It needs the app_usage scope consented.',
      );
    }
    return ListView.separated(
      itemCount: apps.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final app = apps[i];
        final pkg = (app['package'] ?? '—').toString();
        final name = (app['name'] ?? pkg).toString();
        final version = app['version']?.toString();
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.apps)),
          title: Text(name),
          subtitle: Text(
            version == null || version.isEmpty ? pkg : '$pkg · v$version',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
          trailing: (app['system'] == true)
              ? const Chip(label: Text('System'))
              : null,
        );
      },
    );
  }

  Widget _buildUsage(ThemeData theme, AppTokens tokens) {
    final apps = _usageApps;
    if (apps.isEmpty) {
      return const EmptyState(
        title: 'No app usage yet',
        message:
            'The device has not reported app usage. It needs Usage Access '
            'granted and the app_usage scope consented.',
      );
    }
    return ListView.separated(
      itemCount: apps.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final app = apps[i];
        final pkg = (app['package'] ?? app['package_name'] ?? '—').toString();
        final name = (app['name'] ?? app['app_name'] ?? pkg).toString();
        final fgMs = _int(
          app['foreground_ms'] ??
              app['total_time_foreground_ms'] ??
              app['usage_ms'],
        );
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.apps)),
          title: Text(name),
          subtitle: Text(
            pkg,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
          trailing: fgMs > 0 ? Text(_fmt(fgMs)) : null,
        );
      },
    );
  }

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _fmt(int ms) {
    final mins = ms ~/ 60000;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

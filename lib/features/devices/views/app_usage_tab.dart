import 'package:flutter/material.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/app/routes.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/devices/models/device_event_model.dart';
import 'package:spy_love/shared/widgets/app_states.dart';

/// Monitor-side view of the most recent `app_usage.snapshot` the device
/// uploaded: which apps were used and for how long over the reporting window.
///
/// This is the backend-sourced "apps" list available today. A full installed-app
/// inventory (every app, not just recently used) needs an `app_inventory.*`
/// collector + event; see PR notes.
class AppUsageTab extends StatelessWidget {
  const AppUsageTab({
    super.key,
    required this.events,
    required this.isLoading,
  });

  final List<DeviceEventModel> events;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    if (isLoading && events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Latest snapshot carries the richest app list.
    final snapshot = events.isEmpty ? null : events.first;
    final apps = _appsFrom(snapshot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.apps),
            label: const Text('View all installed apps (this device)'),
            onPressed: () => AppNavigator.toNamed(AppRoutes.installedApps),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: apps.isEmpty
              ? const EmptyState(
                  title: 'No app usage yet',
                  message:
                      'The device has not reported app usage. It needs Usage Access granted and the app_usage scope consented.',
                )
              : ListView.separated(
                  itemCount: apps.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final app = apps[i];
                    final pkg =
                        (app['package'] ?? app['package_name'] ?? '—').toString();
                    final name = (app['name'] ?? app['app_name'] ?? pkg).toString();
                    final fgMs = _int(app['foreground_ms'] ??
                        app['total_time_foreground_ms'] ??
                        app['usage_ms']);
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.apps)),
                      title: Text(name),
                      subtitle: Text(
                        pkg,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: tokens.secondaryText),
                      ),
                      trailing: fgMs > 0 ? Text(_fmt(fgMs)) : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _appsFrom(DeviceEventModel? snapshot) {
    if (snapshot == null) return const [];
    final raw = snapshot.payload['apps'];
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

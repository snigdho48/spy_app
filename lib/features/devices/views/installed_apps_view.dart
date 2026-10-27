import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/features/monitoring/installed_apps_bridge.dart';
import 'package:spy_love/shared/widgets/app_states.dart';

/// On-device inventory of ALL installed apps (name, icon, package) available to
/// the monitor. Searchable; toggles system apps.
///
/// NOTE: this lists apps on the *current* device. The monitor sees a remote
/// device's installed apps in [RemoteAppsTab], which reads
/// `app_inventory.snapshot` uploaded by the device-side collector; this screen
/// is the on-device source for that collector.
class InstalledAppsView extends StatefulWidget {
  const InstalledAppsView({super.key});

  @override
  State<InstalledAppsView> createState() => _InstalledAppsViewState();
}

class _InstalledAppsViewState extends State<InstalledAppsView> {
  List<Map<String, dynamic>> _apps = const [];
  bool _loading = true;
  bool _includeSystem = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final apps =
        await InstalledAppsBridge.getInstalledApps(includeSystem: _includeSystem);
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _apps;
    return _apps.where((a) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      final pkg = (a['package'] ?? '').toString().toLowerCase();
      return name.contains(q) || pkg.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installed apps'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search apps or package names',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SwitchListTile(
            value: _includeSystem,
            title: const Text('Include system apps'),
            onChanged: (v) {
              setState(() => _includeSystem = v);
              _load();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? const EmptyState(
                        title: 'No apps found',
                        message:
                            'Either no apps match, or app visibility is not granted on this platform.',
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final app = items[i];
                          final icon = app['icon'] as String?;
                          return ListTile(
                            leading: _AppIcon(base64Png: icon),
                            title: Text(app['name']?.toString() ?? '—'),
                            subtitle: Text(
                              app['package']?.toString() ?? '',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: tokens.secondaryText),
                            ),
                            trailing: (app['system'] == true)
                                ? const Chip(label: Text('System'))
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({this.base64Png});

  final String? base64Png;

  @override
  Widget build(BuildContext context) {
    final b64 = base64Png;
    if (b64 == null || b64.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.apps));
    }
    try {
      return CircleAvatar(backgroundImage: MemoryImage(base64Decode(b64)));
    } catch (_) {
      return const CircleAvatar(child: Icon(Icons.apps));
    }
  }
}

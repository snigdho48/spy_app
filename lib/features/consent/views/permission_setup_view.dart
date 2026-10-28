import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spy_love/core/permissions/system_settings_bridge.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/app_card.dart';
import 'package:spy_love/shared/widgets/app_page.dart';
import 'package:spy_love/shared/widgets/status_badge.dart';

/// How a permission is granted on the OS.
enum _GrantKind {
  /// Standard Android/iOS runtime request (permission_handler).
  runtime,

  /// No runtime API — can only be toggled on a specific system settings page.
  settingsOnly,
}

/// A single permission row descriptor.
class _PermItem {
  const _PermItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.kind,
    this.permission,
    this.settingsPage,
    this.androidOnly = false,
  });

  final String key;
  final IconData icon;
  final String title;
  final String description;
  final _GrantKind kind;

  /// For [_GrantKind.runtime].
  final Permission? permission;

  /// For [_GrantKind.settingsOnly] (and the deep-link for a permanently-denied
  /// runtime permission).
  final SystemSettingsPage? settingsPage;
  final bool androidOnly;
}

/// Detailed, per-permission setup screen.
///
/// Each capability shows its own row with a description and a Grant button.
/// Runtime permissions trigger the real OS request; if permanently denied they
/// deep-link to the exact system settings page. Settings-only capabilities
/// (accessibility, usage access, notification listener, overlay, battery
/// exemption, device admin) deep-link straight to the right page. Live status
/// is reflected per row and refreshed whenever the app resumes.
class PermissionSetupView extends StatefulWidget {
  const PermissionSetupView({super.key});

  @override
  State<PermissionSetupView> createState() => _PermissionSetupViewState();
}

class _PermissionSetupViewState extends State<PermissionSetupView>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('org.hmg.spy_love/monitoring');

  /// Runtime permission statuses keyed by [_PermItem.key].
  final Map<String, PermissionStatus> _runtime = {};

  /// Settings-only tri-state: true granted, false not granted, null unknown.
  final Map<String, bool?> _settings = {};

  bool _busy = false;

  late final List<_PermItem> _items = _buildItems();

  List<_PermItem> _buildItems() {
    return [
      const _PermItem(
        key: 'location',
        icon: Icons.location_on_outlined,
        title: 'Location',
        description: 'Share live location and location history when consented.',
        kind: _GrantKind.runtime,
        permission: Permission.locationWhenInUse,
      ),
      _PermItem(
        key: 'location_always',
        icon: Icons.my_location_outlined,
        title: 'Background location',
        description:
            'Keep sharing location while the app is in the background.',
        kind: _GrantKind.runtime,
        permission: Permission.locationAlways,
        androidOnly: Platform.isAndroid,
      ),
      const _PermItem(
        key: 'contacts',
        icon: Icons.contacts_outlined,
        title: 'Contacts',
        description: 'Resolve names for calls and messages from your contacts.',
        kind: _GrantKind.runtime,
        permission: Permission.contacts,
      ),
      const _PermItem(
        key: 'sms',
        icon: Icons.sms_outlined,
        title: 'SMS',
        description: 'Read SMS history to show it in the monitor view.',
        kind: _GrantKind.runtime,
        permission: Permission.sms,
        androidOnly: true,
      ),
      const _PermItem(
        key: 'phone',
        icon: Icons.call_outlined,
        title: 'Phone & call log',
        description:
            'Read call history (numbers, duration, type) and SIM info.',
        kind: _GrantKind.runtime,
        permission: Permission.phone,
        androidOnly: true,
      ),
      const _PermItem(
        key: 'microphone',
        icon: Icons.mic_none_outlined,
        title: 'Microphone',
        description: 'Required for any voice capture features you consent to.',
        kind: _GrantKind.runtime,
        permission: Permission.microphone,
      ),
      const _PermItem(
        key: 'camera',
        icon: Icons.photo_camera_outlined,
        title: 'Camera',
        description: 'Scan pairing QR codes and any consented camera features.',
        kind: _GrantKind.runtime,
        permission: Permission.camera,
      ),
      const _PermItem(
        key: 'notification',
        icon: Icons.notifications_active_outlined,
        title: 'Notifications',
        description: 'Show the persistent monitoring status notification.',
        kind: _GrantKind.runtime,
        permission: Permission.notification,
      ),
      const _PermItem(
        key: 'accessibility',
        icon: Icons.accessibility_new_outlined,
        title: 'Accessibility service',
        description:
            'Enables richer on-screen context for consented safety features.',
        kind: _GrantKind.settingsOnly,
        settingsPage: SystemSettingsPage.accessibility,
        androidOnly: true,
      ),
      const _PermItem(
        key: 'usage_access',
        icon: Icons.query_stats_outlined,
        title: 'Usage access',
        description:
            'Report which apps are used and for how long (screen time).',
        kind: _GrantKind.settingsOnly,
        settingsPage: SystemSettingsPage.usageAccess,
        androidOnly: true,
      ),
      const _PermItem(
        key: 'notification_listener',
        icon: Icons.hearing_outlined,
        title: 'Notification access',
        description:
            'Surface chat/notification activity from WhatsApp, Messenger, etc.',
        kind: _GrantKind.settingsOnly,
        settingsPage: SystemSettingsPage.notificationListener,
        androidOnly: true,
      ),
      _PermItem(
        key: 'overlay',
        icon: Icons.layers_outlined,
        title: 'Display over other apps',
        description: 'Show the always-visible "sharing active" overlay banner.',
        kind: _GrantKind.runtime,
        permission: Permission.systemAlertWindow,
        settingsPage: SystemSettingsPage.overlay,
        androidOnly: Platform.isAndroid,
      ),
      const _PermItem(
        key: 'screen_capture',
        icon: Icons.screen_share_outlined,
        title: 'Screen capture',
        description:
            'Live screen view asks for the system MediaProjection grant each '
            'session — there is nothing to pre-enable here.',
        kind: _GrantKind.settingsOnly,
        settingsPage: SystemSettingsPage.appDetails,
        androidOnly: true,
      ),
      _PermItem(
        key: 'battery',
        icon: Icons.battery_charging_full_outlined,
        title: 'Battery optimization exemption',
        description: 'Keep monitoring reliable by exempting the app from Doze.',
        kind: _GrantKind.runtime,
        permission: Permission.ignoreBatteryOptimizations,
        settingsPage: SystemSettingsPage.batteryOptimization,
        androidOnly: Platform.isAndroid,
      ),
      const _PermItem(
        key: 'device_admin',
        icon: Icons.admin_panel_settings_outlined,
        title: 'Device admin',
        description: 'Optional: stronger anti-tamper protection for the link.',
        kind: _GrantKind.settingsOnly,
        settingsPage: SystemSettingsPage.deviceAdmin,
        androidOnly: true,
      ),
    ];
  }

  List<_PermItem> get _visibleItems =>
      _items.where((i) => !i.androidOnly || Platform.isAndroid).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  Future<void> _refreshAll() async {
    for (final item in _visibleItems) {
      if (item.kind == _GrantKind.runtime && item.permission != null) {
        _runtime[item.key] = await item.permission!.status;
      } else if (item.kind == _GrantKind.settingsOnly) {
        _settings[item.key] = await _querySettingsState(item.key);
      }
    }
    if (mounted) setState(() {});
  }

  /// Best-effort native status for settings-only permissions. Returns null when
  /// the native build cannot report it (then the row shows "Check").
  Future<bool?> _querySettingsState(String key) async {
    try {
      return await _channel.invokeMethod<bool>('getSettingsPermissionState', {
        'page': key,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  bool _isGranted(PermissionStatus? s) =>
      s == PermissionStatus.granted || s == PermissionStatus.limited;

  int get _grantedCount {
    var n = 0;
    for (final item in _visibleItems) {
      if (item.kind == _GrantKind.runtime) {
        if (_isGranted(_runtime[item.key])) n++;
      } else if (_settings[item.key] == true) {
        n++;
      }
    }
    return n;
  }

  Future<void> _onGrant(_PermItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (item.kind == _GrantKind.runtime && item.permission != null) {
        final current = await item.permission!.status;
        if (current.isPermanentlyDenied || current.isRestricted) {
          await SystemSettingsBridge.open(
            item.settingsPage ?? SystemSettingsPage.appDetails,
          );
        } else {
          _runtime[item.key] = await item.permission!.request();
        }
      } else {
        await SystemSettingsBridge.open(
          item.settingsPage ?? SystemSettingsPage.appDetails,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final items = _visibleItems;
    final progress = items.isEmpty ? 0.0 : _grantedCount / items.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Device permissions'),
            Text(
              '● MUTUAL TRANSPARENCY ACTIVE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: tokens.consented,
              ),
            ),
          ],
        ),
      ),
      body: AppPage(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: tokens.surfaceContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$_grantedCount / ${items.length}',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Grant each capability', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap Grant to trigger the real system request. If a permission was '
            'permanently denied, Grant opens the exact settings page to re-enable '
            'it. Spy Love never runs hidden.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in items) ...[
            _PermissionRow(
              item: item,
              status: _statusFor(item),
              busy: _busy,
              onGrant: () => _onGrant(item),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Done',
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Review installed apps',
            icon: Icons.apps,
            variant: AppButtonVariant.soft,
            onPressed: () => Navigator.of(context).pushNamed('/apps/installed'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Revocable anytime in device Settings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  _RowStatus _statusFor(_PermItem item) {
    if (item.kind == _GrantKind.runtime) {
      final s = _runtime[item.key];
      if (_isGranted(s)) return _RowStatus.granted;
      if (s == PermissionStatus.permanentlyDenied ||
          s == PermissionStatus.restricted) {
        return _RowStatus.blocked;
      }
      return _RowStatus.denied;
    }
    final v = _settings[item.key];
    if (v == true) return _RowStatus.granted;
    if (v == false) return _RowStatus.denied;
    return _RowStatus.unknown;
  }
}

enum _RowStatus { granted, denied, blocked, unknown }

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.item,
    required this.status,
    required this.busy,
    required this.onGrant,
  });

  final _PermItem item;
  final _RowStatus status;
  final bool busy;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final (label, tone) = switch (status) {
      _RowStatus.granted => ('Granted', StatusTone.success),
      _RowStatus.denied => ('Not granted', StatusTone.warning),
      _RowStatus.blocked => ('Open settings', StatusTone.danger),
      _RowStatus.unknown => ('Check', StatusTone.neutral),
    };

    final buttonLabel = switch (status) {
      _RowStatus.granted => 'Granted',
      _RowStatus.blocked => 'Open settings',
      _ when item.kind == _GrantKind.settingsOnly => 'Open settings',
      _ => 'Grant',
    };

    return AppCard(
      semanticLabel: '${item.title}, $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                excludeSemantics: true,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(item.title, style: theme.textTheme.titleMedium),
              ),
              StatusBadge(label: label, tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: buttonLabel,
            icon: status == _RowStatus.granted
                ? Icons.check_circle_outline
                : (item.kind == _GrantKind.settingsOnly ||
                      status == _RowStatus.blocked)
                ? Icons.open_in_new
                : Icons.lock_open_outlined,
            variant: status == _RowStatus.granted
                ? AppButtonVariant.soft
                : AppButtonVariant.primary,
            onPressed: (busy || status == _RowStatus.granted) ? null : onGrant,
          ),
        ],
      ),
    );
  }
}

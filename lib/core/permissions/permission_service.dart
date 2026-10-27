import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spy_love/core/permissions/app_permission.dart';

class PermissionService extends ChangeNotifier {
  final Map<String, PermissionStatus> statuses = <String, PermissionStatus>{};

  bool get allGranted =>
      AppPermission.monitoring.every((item) => _isGranted(statuses[item.scope]));

  List<AppPermission> get missingPermissions => AppPermission.monitoring
      .where((item) => !_isGranted(statuses[item.scope]))
      .toList(growable: false);

  Future<void> refreshStatuses() async {
    for (final item in AppPermission.monitoring) {
      statuses[item.scope] = await item.permission.status;
    }

    if (Platform.isAndroid) {
      statuses['location_background'] = await Permission.locationAlways.status;
    }
    notifyListeners();
  }

  Future<bool> requestMonitoringPermissions() async {
    await _requestLocation();
    await _request(AppPermission.monitoring[1]);
    await _request(AppPermission.monitoring[2]);

    if (Platform.isAndroid) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    await refreshStatuses();
    return allGranted;
  }

  Future<bool> requestScope(String scope) async {
    AppPermission? item;
    for (final permission in AppPermission.monitoring) {
      if (permission.scope == scope) {
        item = permission;
        break;
      }
    }
    if (item == null) return true;

    if (scope == 'location') {
      await _requestLocation();
    } else {
      await _request(item);
    }

    await refreshStatuses();
    return _isGranted(statuses[scope]);
  }

  Future<void> openAppSettingsPage() => openAppSettings();

  bool _isGranted(PermissionStatus? status) =>
      status == PermissionStatus.granted || status == PermissionStatus.limited;

  Future<void> _request(AppPermission item) async {
    statuses[item.scope] = await item.permission.request();
  }

  Future<void> _requestLocation() async {
    var status = await Permission.locationWhenInUse.request();
    statuses['location'] = status;

    if (!Platform.isAndroid || !_isGranted(status)) return;

    final background = await Permission.locationAlways.request();
    statuses['location_background'] = background;

    if (_isGranted(background)) {
      statuses['location'] = PermissionStatus.granted;
    }
  }
}

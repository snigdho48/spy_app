import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spy_love/features/alerts/models/alert_model.dart';
import 'package:spy_love/features/alerts/repositories/alert_repository.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';

/// Drives the Alerts center list, filters, unread badge and read/delete
/// actions. Background polling always uses the repository's loader:false path
/// so the global overlay never trips during a silent refresh.
class AlertsController extends ChangeNotifier {
  AlertsController(this._repository, this._auth) {
    _auth.addListener(_onAuthChanged);
    _wasLoggedIn = _auth.isLoggedIn;
    if (_wasLoggedIn) {
      refresh();
      _startPolling();
    }
  }

  final AlertRepository _repository;
  final AuthController _auth;
  bool _wasLoggedIn = false;
  Timer? _pollTimer;

  final List<AlertModel> alerts = <AlertModel>[];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool _hasNext = false;
  int _page = 1;
  int unreadCount = 0;
  String errorMessage = '';

  AlertType? typeFilter;
  bool unreadOnly = false;

  /// Optional per-device scope (used by the device-detail Alerts tab).
  String? deviceId;

  /// VIEWER role cannot delete; the destructive swipe action is hidden.
  bool get canDelete {
    final role = _auth.user?.role?.toUpperCase();
    return role != 'VIEWER';
  }

  bool get hasNext => _hasNext;

  void _onAuthChanged() {
    final loggedIn = _auth.isLoggedIn;
    if (loggedIn == _wasLoggedIn) return;
    _wasLoggedIn = loggedIn;
    if (loggedIn) {
      refresh();
      _startPolling();
    } else {
      _pollTimer?.cancel();
      alerts.clear();
      unreadCount = 0;
      errorMessage = '';
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(refreshUnreadBadge());
    });
  }

  void setDeviceScope(String? id) {
    if (deviceId == id) return;
    deviceId = id;
    unawaited(refresh());
  }

  void setTypeFilter(AlertType? type) {
    typeFilter = type;
    unawaited(refresh());
  }

  void toggleUnreadOnly() {
    unreadOnly = !unreadOnly;
    unawaited(refresh());
  }

  Future<void> refresh({bool silent = false}) async {
    if (!_auth.isLoggedIn) return;
    _page = 1;
    if (!silent) {
      isLoading = true;
      errorMessage = '';
      notifyListeners();
    }
    final result = await _repository.list(
      deviceId: deviceId,
      type: typeFilter,
      unreadOnly: unreadOnly,
      page: _page,
      loader: false,
    );
    result.fold((page) {
      alerts
        ..clear()
        ..addAll(page.alerts);
      _hasNext = page.hasNext;
      errorMessage = '';
    }, (error) => errorMessage = error);
    isLoading = false;
    await refreshUnreadBadge();
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !_hasNext) return;
    isLoadingMore = true;
    notifyListeners();
    final result = await _repository.list(
      deviceId: deviceId,
      type: typeFilter,
      unreadOnly: unreadOnly,
      page: _page + 1,
      loader: false,
    );
    result.fold((page) {
      _page += 1;
      alerts.addAll(page.alerts);
      _hasNext = page.hasNext;
    }, (_) {});
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> refreshUnreadBadge() async {
    if (!_auth.isLoggedIn) return;
    unreadCount = await _repository.unreadCount(deviceId: deviceId);
    notifyListeners();
  }

  /// Mark a single alert read (on open). Optimistic; reconciles the badge.
  Future<void> markRead(String id) async {
    final index = alerts.indexWhere((a) => a.id == id);
    if (index == -1 || alerts[index].isRead) return;
    alerts[index] = alerts[index].copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
    if (unreadCount > 0) unreadCount -= 1;
    notifyListeners();
    await _repository.markRead(id);
    await refreshUnreadBadge();
  }

  Future<void> markAllRead() async {
    final result = await _repository.markAllRead(deviceId: deviceId);
    result.fold((_) {
      for (var i = 0; i < alerts.length; i++) {
        if (!alerts[i].isRead) {
          alerts[i] = alerts[i].copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }
      }
      unreadCount = 0;
      notifyListeners();
    }, (_) {});
  }

  /// Returns true on success. On 403 (VIEWER) the caller restores the row.
  Future<bool> delete(String id) async {
    final index = alerts.indexWhere((a) => a.id == id);
    AlertModel? removed;
    if (index != -1) {
      removed = alerts.removeAt(index);
      notifyListeners();
    }
    final result = await _repository.delete(id);
    return result.fold((_) {
      unawaited(refreshUnreadBadge());
      return true;
    }, (_) {
      if (removed != null && index != -1) {
        alerts.insert(index, removed);
        notifyListeners();
      }
      return false;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

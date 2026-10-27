import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_request/one_request.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';

/// App-facing online flag. Notices themselves come from [OneRequest.setConnectivity].
class NetworkService extends ChangeNotifier {
  NetworkService() {
    _subscription = OneRequest.connectivity.listen(_apply);
    unawaited(refreshStatus());
  }

  StreamSubscription<ConnectivityStatus>? _subscription;
  bool isConnected = true;

  Future<void> refreshStatus() async {
    _apply(await OneRequest.checkConnectivity());
  }

  void _apply(ConnectivityStatus status) {
    final wasConnected = isConnected;
    if (status.online == wasConnected) return;
    isConnected = status.online;
    notifyListeners();
    if (!wasConnected && status.online) {
      AppNavigator.snackbar(
        'Back online',
        'Your connection is restored.',
        icon: Icons.wifi,
      );
    }
  }

  /// Blocks a user action while offline. The package snackbar covers the notice.
  Future<bool> ensureConnected({bool showMessage = false}) async {
    await refreshStatus();
    if (isConnected) return true;

    if (showMessage) {
      AppNavigator.snackbar('No connection', 'Check your internet and try again.');
    }
    return false;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

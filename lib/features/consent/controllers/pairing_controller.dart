import 'dart:async';

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spy_love/features/monitoring/monitored_device_storage.dart';
import 'package:spy_love/features/monitoring/monitoring_service.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/permissions/permission_service.dart';
import 'package:spy_love/core/storage/device_fingerprint_storage.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/devices/controllers/dashboard_controller.dart';
import 'package:spy_love/features/devices/models/device_model.dart';
import 'package:spy_love/features/devices/repositories/device_repository.dart';
import 'package:spy_love/features/consent/models/consent_scope.dart';
import 'package:spy_love/features/consent/models/pairing_initiate_result.dart';
import 'package:spy_love/features/consent/views/pairing_success_view.dart';

class PairingController extends ChangeNotifier {
  PairingController(
    this._repository,
    this._fingerprintStorage,
    this._permissionService,
    this._auth,
    this._monitoring,
    this._dashboard,
  ) {
    deviceName = defaultDeviceName;
    deviceNameController = TextEditingController(text: defaultDeviceName);
    _auth.addListener(_onAuthChanged);
    unawaited(_resumePendingWatch());
  }

  final DeviceRepository _repository;
  final DeviceFingerprintStorage _fingerprintStorage;
  final PermissionService _permissionService;
  final AuthController _auth;
  final MonitoringService _monitoring;
  final DashboardController _dashboard;

  bool isLoading = false;
  String errorMessage = '';
  PairingInitiateResult? activePairing;
  bool isWatchingApproval = false;
  String deviceName = '';
  String pairingCodeInput = '';
  Set<String> selectedScopes = {
    'call_log',
    'sms',
    'messaging',
    'sim',
    'location',
    'battery',
    'network',
    'app_usage',
    'device_info',
  };
  bool useScanner = false;

  Timer? _activationTimer;
  bool _activationHandled = false;
  bool _pollInFlight = false;
  String? _watchedDeviceId;

  /// Bumped when the signed-in user is cleared so an in-flight approval poll
  /// cannot mark the device linked or start collectors after logout.
  int _watchGeneration = 0;

  late final TextEditingController deviceNameController;

  String get defaultDeviceName {
    if (kIsWeb) return 'Web browser';
    if (!kIsWeb && Platform.isAndroid) return 'Android phone';
    if (!kIsWeb && Platform.isIOS) return 'iPhone';
    return 'My device';
  }

  String get platform {
    if (kIsWeb) return 'web';
    if (!kIsWeb && Platform.isAndroid) return 'android';
    if (!kIsWeb && Platform.isIOS) return 'ios';
    return 'other';
  }

  void _onAuthChanged() {
    if (_auth.user != null) return;
    _watchGeneration++;
    _activationHandled = false;
    activePairing = null;
    _stopActivationWatch();
  }

  Future<void> _resumePendingWatch() async {
    final generation = _watchGeneration;
    if (await MonitoredDeviceStorage.isMarkedLinked()) return;

    var deviceId = await MonitoredDeviceStorage.getPendingDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      // Older builds stored the not-yet-approved id in device_id. Keep watching
      // it, but do not treat it as an approved device.
      final legacyId = await MonitoredDeviceStorage.getDeviceId();
      if (legacyId != null && legacyId.isNotEmpty) {
        deviceId = legacyId;
        await MonitoredDeviceStorage.savePendingDeviceId(legacyId);
      }
    }
    if (generation != _watchGeneration) return;
    if (deviceId == null || deviceId.isEmpty) return;
    if (await MonitoredDeviceStorage.isMarkedLinked()) return;
    if (generation != _watchGeneration) return;
    startActivationWatch(deviceId);
  }

  void toggleScope(String scopeId, bool selected) {
    if (selected) {
      selectedScopes.add(scopeId);
    } else {
      selectedScopes.remove(scopeId);
    }
    notifyListeners();
  }

  Future<void> initiatePairing() async {
    errorMessage = '';
    isLoading = true;
    _activationHandled = false;
    notifyListeners();

    final granted = await _permissionService.requestMonitoringPermissions();
    if (!granted) {
      isLoading = false;
      errorMessage = 'Grant permissions so this device can be monitored.';
      notifyListeners();
      return;
    }

    final fingerprint = await _fingerprintStorage.getOrCreate();
    final name = deviceNameController.text.trim().isEmpty
        ? defaultDeviceName
        : deviceNameController.text.trim();

    final result = await _repository.initiatePairing(
      deviceName: name,
      platform: platform,
      deviceFingerprint: fingerprint,
    );

    result.fold(
      (value) {
        activePairing = value;
        deviceName = name;
        unawaited(_onPairingCreated(value.deviceId));
      },
      (error) => errorMessage = error,
    );
    isLoading = false;
    notifyListeners();
  }

  void startActivationWatch(String deviceId) {
    if (_watchedDeviceId == deviceId && _activationTimer != null) return;

    _stopActivationWatch(keepHandledFlag: true);
    _watchedDeviceId = deviceId;
    isWatchingApproval = true;
    notifyListeners();

    unawaited(_pollActivationOnce(deviceId));

    _activationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollActivationOnce(deviceId));
    });
  }

  void _stopActivationWatch({bool keepHandledFlag = false}) {
    _activationTimer?.cancel();
    _activationTimer = null;
    _watchedDeviceId = null;
    isWatchingApproval = false;
    if (!keepHandledFlag) {
      _activationHandled = false;
    }
    notifyListeners();
  }

  Future<void> _pollActivationOnce(String deviceId) async {
    if (_activationHandled || _pollInFlight || _auth.user == null) return;
    _pollInFlight = true;
    final generation = _watchGeneration;

    try {
      final result = await _repository.getOwnedDeviceStatus(deviceId);
      if (generation != _watchGeneration || _auth.user == null) return;
      result.fold(
        (status) {
          if (status.isLinked) {
            unawaited(_handlePairingActivated(status, generation));
          }
        },
        (_) {},
      );
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _handlePairingActivated(
    OwnedDeviceStatus status,
    int generation,
  ) async {
    if (_activationHandled || generation != _watchGeneration || _auth.user == null) {
      return;
    }
    _activationHandled = true;
    _stopActivationWatch(keepHandledFlag: true);

    activePairing = null;
    notifyListeners();

    if (generation != _watchGeneration || _auth.user == null) return;
    await MonitoredDeviceStorage.markLinked(status.deviceId);
    if (generation != _watchGeneration || _auth.user == null) return;
    await _monitoring.start(status.deviceId);
    if (generation != _watchGeneration || _auth.user == null) {
      await _monitoring.stop();
      return;
    }
    if (generation != _watchGeneration || _auth.user == null) return;
    AppNavigator.popUntilHome();

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (generation != _watchGeneration || _auth.user == null) return;
    AppNavigator.snackbar(
      'Connected',
      'This device is now linked to ${status.tenantName}.',
      icon: Icons.check_circle_outline,
    );
  }

  Future<bool> completePairing() async {
    errorMessage = '';

    if (_auth.user?.needsWorkspace ?? true) {
      errorMessage =
          'Create a monitoring workspace on this account before approving a device.';
      notifyListeners();
      return false;
    }

    final code = _normalizePairingCode(pairingCodeInput);
    if (code.isEmpty) {
      errorMessage = 'Enter a pairing code';
      notifyListeners();
      return false;
    }
    if (selectedScopes.isEmpty) {
      errorMessage = 'Select at least one consent scope';
      notifyListeners();
      return false;
    }

    isLoading = true;
    notifyListeners();
    final result = await _repository.completePairing(
      pairingCode: code,
      consentScopes: selectedScopes.toList(),
      consentVersion: ConsentScope.consentVersion,
    );
    isLoading = false;
    notifyListeners();

    return result.fold(
      (device) {
        unawaited(_dashboard.loadDevices());
        AppNavigator.off(
          PairingSuccessView(
            deviceName: device.name,
            scopeCount: selectedScopes.length,
          ),
        );
        return true;
      },
      (error) {
        errorMessage = error;
        notifyListeners();
        return false;
      },
    );
  }

  void applyScannedPayload(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'spylove' && uri.host == 'pair') {
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        pairingCodeInput = _normalizePairingCode(code);
        useScanner = false;
        notifyListeners();
        return;
      }
    }

    pairingCodeInput = _normalizePairingCode(raw);
    if (pairingCodeInput.isNotEmpty) {
      useScanner = false;
    }
    notifyListeners();
  }

  void setUseScanner(bool value) {
    useScanner = value;
    notifyListeners();
  }

  void setPairingCodeInput(String value) {
    pairingCodeInput = value;
    notifyListeners();
  }

  void clearActivePairing() {
    activePairing = null;
    notifyListeners();
  }

  String _normalizePairingCode(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll('-', '');
    if (cleaned.length == 6 && RegExp(r'^[A-Z0-9]+$').hasMatch(cleaned)) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3)}';
    }
    return raw.trim().toUpperCase();
  }

  Future<void> _onPairingCreated(String deviceId) async {
    await MonitoredDeviceStorage.savePendingDeviceId(deviceId);
    if (_auth.user == null) return;
    startActivationWatch(deviceId);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _stopActivationWatch();
    deviceNameController.dispose();
    super.dispose();
  }
}

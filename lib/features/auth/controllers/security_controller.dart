import 'package:flutter/material.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/auth/models/totp_models.dart';
import 'package:spy_love/features/auth/models/session_models.dart';
import 'package:spy_love/features/auth/repositories/auth_repository.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';

class SecurityController extends ChangeNotifier {
  SecurityController(this._repository, this._auth);

  final AuthRepository _repository;
  final AuthController _auth;

  TotpStatus? status;
  TotpEnrollment? enrollment;
  List<String> recoveryCodes = const [];
  List<AuthSession> sessions = const [];
  bool isLoading = false;
  bool sessionsLoading = false;
  String errorMessage = '';

  Future<void> load() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();
    final result = await _repository.totpStatus();
    result.fold((value) {
      status = value;
    }, (error) => errorMessage = error);
    isLoading = false;
    notifyListeners();
    await loadSessions();
  }

  Future<void> loadSessions() async {
    sessionsLoading = true;
    notifyListeners();
    final result = await _repository.listSessions();
    result.fold((value) {
      sessions = value;
    }, (error) {
      // Soft-fail: keep prior list, surface message
      errorMessage = error;
    });
    sessionsLoading = false;
    notifyListeners();
  }

  Future<void> revokeSession(String id) async {
    final result = await _repository.revokeSession(id);
    result.fold((_) {
      sessions = sessions.where((s) => s.id != id).toList();
      AppNavigator.snackbar('Session revoked', 'That device is signed out');
    }, (error) => errorMessage = error);
    notifyListeners();
  }

  Future<void> revokeOtherSessions() async {
    final result = await _repository.revokeOtherSessions();
    result.fold((count) {
      sessions = sessions.where((s) => s.isCurrent).toList();
      AppNavigator.snackbar(
        'Signed out elsewhere',
        count == 1 ? '1 other session revoked' : '$count other sessions revoked',
      );
    }, (error) => errorMessage = error);
    notifyListeners();
  }

  Future<void> startEnroll() async {
    errorMessage = '';
    recoveryCodes = const [];
    notifyListeners();
    final result = await _repository.totpEnroll();
    result.fold((value) {
      enrollment = value;
    }, (error) => errorMessage = error);
    notifyListeners();
  }

  Future<bool> confirmEnroll(String code) async {
    errorMessage = '';
    notifyListeners();
    final result = await _repository.totpConfirm(code);
    var ok = false;
    result.fold((codes) {
      recoveryCodes = codes;
      enrollment = null;
      status = TotpStatus(
        enabled: true,
        confirmedAt: DateTime.now(),
        recoveryCodesRemaining: codes.length,
      );
      final user = _auth.user;
      if (user != null) {
        _auth.applyUser(user.copyWith(totpEnabled: true));
      }
      AppNavigator.snackbar(
        'Two-factor enabled',
        'Save your recovery codes somewhere safe',
      );
      ok = true;
    }, (error) => errorMessage = error);
    notifyListeners();
    return ok;
  }

  Future<bool> disable({String? password, String? code}) async {
    errorMessage = '';
    notifyListeners();
    final result = await _repository.totpDisable(
      password: password,
      code: code,
    );
    var ok = false;
    result.fold((_) {
      status = const TotpStatus(enabled: false);
      recoveryCodes = const [];
      enrollment = null;
      final user = _auth.user;
      if (user != null) {
        _auth.applyUser(user.copyWith(totpEnabled: false));
      }
      AppNavigator.snackbar('Two-factor disabled', 'Authenticator no longer required');
      ok = true;
    }, (error) => errorMessage = error);
    notifyListeners();
    return ok;
  }

  Future<void> regenerateRecovery({String? password, String? code}) async {
    errorMessage = '';
    notifyListeners();
    final result = await _repository.totpRegenerateRecovery(
      password: password,
      code: code,
    );
    result.fold((codes) {
      recoveryCodes = codes;
      if (status != null) {
        status = TotpStatus(
          enabled: status!.enabled,
          confirmedAt: status!.confirmedAt,
          recoveryCodesRemaining: codes.length,
        );
      }
      AppNavigator.snackbar('Recovery codes refreshed', 'Previous codes no longer work');
    }, (error) => errorMessage = error);
    notifyListeners();
  }

  void clearEnrollment() {
    enrollment = null;
    notifyListeners();
  }

  void clearRecoveryCodes() {
    recoveryCodes = const [];
    notifyListeners();
  }
}

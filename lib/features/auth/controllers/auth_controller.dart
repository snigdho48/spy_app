import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/features/monitoring/monitoring_service.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/features/auth/models/auth_user.dart';
import 'package:spy_love/features/auth/repositories/auth_repository.dart';
import 'package:spy_love/features/subscription/controllers/subscription_controller.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository, this._monitoring);

  final AuthRepository _repository;
  final MonitoringService _monitoring;
  SubscriptionController? _subscription;

  AuthUser? user;
  bool isLoading = false;
  bool isGoogleLoading = false;
  String errorMessage = '';

  bool get isLoggedIn => user != null;

  void bindSubscription(SubscriptionController subscription) {
    _subscription = subscription;
  }

  Future<void> restoreSession() async {
    isLoading = true;
    notifyListeners();
    final result = await _repository.getCurrentUser();
    result.fold(
      (value) {
        user = value;
        _syncSubscription(value);
        if (value != null) {
          _bootstrapMonitoring();
        }
      },
      (error) => errorMessage = error,
    );
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final result = await _repository.getCurrentUser();
    result.fold(
      (value) {
        user = value;
        _syncSubscription(value);
      },
      (error) => errorMessage = error,
    );
    notifyListeners();
  }

  void applyUser(AuthUser next) {
    user = next;
    notifyListeners();
  }

  void _syncSubscription(AuthUser? value) {
    _subscription?.applyFromUser(value);
  }

  void _bootstrapMonitoring() {
    unawaited(_monitoring.bootstrap());
  }

  Future<void> login(String email, String password) async {
    errorMessage = '';
    notifyListeners();
    final result = await _repository.login(email: email, password: password);
    result.fold(
      (value) {
        user = value;
        _syncSubscription(value);
        _bootstrapMonitoring();
        AppNavigator.popUntilHome();
      },
      (error) => errorMessage = error,
    );
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String tenantName,
  }) async {
    errorMessage = '';
    notifyListeners();
    final result = await _repository.register(
      email: email,
      password: password,
      fullName: fullName,
      tenantName: tenantName,
    );
    result.fold(
      (value) {
        user = value;
        _syncSubscription(value);
        _bootstrapMonitoring();
        AppNavigator.popUntilHome();
      },
      (error) => errorMessage = error,
    );
    notifyListeners();
  }

  Future<void> loginWithGoogle({BuildContext? context}) async {
    errorMessage = '';
    isGoogleLoading = true;
    notifyListeners();

    try {
      final idToken = await _repository.obtainGoogleIdToken();
      if (idToken == null) {
        isGoogleLoading = false;
        notifyListeners();
        return;
      }

      var result = await _repository.signInWithGoogle(idToken: idToken);

      if (result.isRight && result.right == ApiConstants.tenantRequiredError) {
        final tenantName = await _promptTenantName(context ?? AppNavigator.context);
        if (tenantName == null || tenantName.isEmpty) {
          isGoogleLoading = false;
          notifyListeners();
          return;
        }
        result = await _repository.signInWithGoogle(
          idToken: idToken,
          tenantName: tenantName,
        );
      }

      result.fold(
        (value) {
          user = value;
          _syncSubscription(value);
          _bootstrapMonitoring();
          AppNavigator.popUntilHome();
        },
        (error) => errorMessage = error,
      );
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        errorMessage = e.description ?? 'Google sign-in failed';
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isGoogleLoading = false;
      notifyListeners();
    }
  }

  Future<void> linkGoogleAccount() async {
    errorMessage = '';
    isGoogleLoading = true;
    notifyListeners();

    try {
      final idToken = await _repository.obtainGoogleIdToken();
      if (idToken == null) {
        isGoogleLoading = false;
        notifyListeners();
        return;
      }

      final result = await _repository.linkGoogle(idToken: idToken);
      result.fold(
        (methods) {
          final current = user;
          if (current != null) {
            user = current.copyWith(authMethods: methods);
          }
          AppNavigator.snackbar('Account linked', 'Google sign-in is now enabled for this account');
        },
        (error) => errorMessage = error,
      );
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        errorMessage = e.description ?? 'Google linking failed';
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isGoogleLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPassword(String password) async {
    errorMessage = '';
    notifyListeners();
    final result = await _repository.setPassword(password: password);
    result.fold(
      (methods) {
        final current = user;
        if (current != null) {
          user = current.copyWith(authMethods: methods);
        }
        AppNavigator.snackbar('Password set', 'You can now sign in with email and password');
      },
      (error) => errorMessage = error,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _repository.logout();
    user = null;
    notifyListeners();
    AppNavigator.popUntilHome();
  }

  Future<String?> _promptTenantName(BuildContext? context) async {
    if (context == null) return null;

    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Organization name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Organization Name',
            hintText: 'Your workspace or team name',
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

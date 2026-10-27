import 'package:flutter/material.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/features/auth/controllers/auth_controller.dart';
import 'package:spy_love/features/auth/models/auth_user.dart';
import 'package:spy_love/features/subscription/models/subscription_models.dart';
import 'package:spy_love/features/subscription/repositories/subscription_repository.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController(this._repository);

  final SubscriptionRepository _repository;
  AuthController? _auth;
  bool _wasLoggedIn = false;

  List<SubscriptionPlan> plans = <SubscriptionPlan>[];
  SubscriptionInfo? current;
  bool needsWorkspace = false;
  bool isLoading = false;
  String errorMessage = '';

  void bindAuth(AuthController auth) {
    _auth?.removeListener(_onAuthChanged);
    _auth = auth;
    _auth!.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final loggedIn = _auth?.isLoggedIn ?? false;
    if (loggedIn == _wasLoggedIn) return;
    _wasLoggedIn = loggedIn;
    if (loggedIn) {
      applyFromUser(_auth?.user);
      loadPlans();
      loadCurrent();
    } else {
      plans = <SubscriptionPlan>[];
      current = null;
      needsWorkspace = true;
      errorMessage = '';
      notifyListeners();
    }
  }

  void applyFromUser(AuthUser? value) {
    needsWorkspace = value?.needsWorkspace ?? true;
    current = value?.subscription;
    notifyListeners();
  }

  Future<void> loadPlans() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();
    final result = await _repository.listPlans();
    result.fold(
      (list) => plans = list,
      (error) => errorMessage = error,
    );
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadCurrent() async {
    final result = await _repository.getCurrent();
    result.fold(
      (data) {
        needsWorkspace = data['needs_workspace'] as bool? ?? false;
        final sub = data['subscription'];
        if (sub is Map<String, dynamic>) {
          current = SubscriptionInfo.fromJson(sub);
        } else {
          current = null;
        }
      },
      (error) => errorMessage = error,
    );
    notifyListeners();
  }

  Future<bool> subscribe(String planCode) async {
    errorMessage = '';
    notifyListeners();
    final result = await _repository.subscribe(planCode);
    return result.fold(
      (info) {
        current = info;
        _syncAuthUser(info);
        AppNavigator.snackbar('Plan updated', 'You are now on ${info.planName}');
        notifyListeners();
        return true;
      },
      (error) {
        errorMessage = error;
        notifyListeners();
        return false;
      },
    );
  }

  Future<bool> createWorkspace(String name) async {
    errorMessage = '';
    notifyListeners();
    final result = await _repository.createWorkspace(name);
    return result.fold(
      (data) {
        needsWorkspace = false;
        final sub = data['subscription'];
        if (sub is Map<String, dynamic>) {
          current = SubscriptionInfo.fromJson(sub);
        }
        final tenant = data['tenant'] as Map<String, dynamic>?;
        final auth = _auth;
        final user = auth?.user;
        if (auth != null && user != null && tenant != null) {
          auth.applyUser(
            user.copyWith(
              tenantName: tenant['name'] as String?,
              role: data['role'] as String?,
              needsWorkspace: false,
              subscription: current,
            ),
          );
        }
        AppNavigator.snackbar('Workspace ready', 'You can now pair devices and monitor.');
        notifyListeners();
        return true;
      },
      (error) {
        errorMessage = error;
        notifyListeners();
        return false;
      },
    );
  }

  void _syncAuthUser(SubscriptionInfo info) {
    final auth = _auth;
    final user = auth?.user;
    if (auth != null && user != null) {
      auth.applyUser(user.copyWith(subscription: info));
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }
}

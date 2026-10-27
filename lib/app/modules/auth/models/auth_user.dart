import 'package:spy_love/app/modules/auth/models/auth_methods.dart';
import 'package:spy_love/app/modules/subscription/models/subscription_models.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.tenantName,
    this.role,
    this.needsWorkspace = false,
    this.subscription,
    this.authMethods = const AuthMethods(hasPassword: false, hasGoogle: false),
  });

  final String id;
  final String email;
  final String fullName;
  final String? tenantName;
  final String? role;
  final bool needsWorkspace;
  final SubscriptionInfo? subscription;
  final AuthMethods authMethods;

  bool get hasWorkspace => !needsWorkspace && tenantName != null;

  AuthUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? tenantName,
    String? role,
    bool? needsWorkspace,
    SubscriptionInfo? subscription,
    AuthMethods? authMethods,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      tenantName: tenantName ?? this.tenantName,
      role: role ?? this.role,
      needsWorkspace: needsWorkspace ?? this.needsWorkspace,
      subscription: subscription ?? this.subscription,
      authMethods: authMethods ?? this.authMethods,
    );
  }

  factory AuthUser.fromAuthResponse(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;
    final tenant = data['tenant'] as Map<String, dynamic>?;
    final sub = data['subscription'] as Map<String, dynamic>?;
    return AuthUser(
      id: user['id'].toString(),
      email: user['email'] as String,
      fullName: user['full_name'] as String? ?? '',
      tenantName: tenant?['name'] as String?,
      role: data['role'] as String?,
      needsWorkspace: data['needs_workspace'] as bool? ?? tenant == null,
      subscription: sub != null ? SubscriptionInfo.fromJson(sub) : null,
      authMethods: AuthMethods.fromJson(data['auth_methods'] as Map<String, dynamic>?),
    );
  }

  factory AuthUser.fromMeResponse(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;
    final tenant = data['tenant'] as Map<String, dynamic>?;
    final sub = data['subscription'] as Map<String, dynamic>?;
    return AuthUser(
      id: user['id'].toString(),
      email: user['email'] as String,
      fullName: user['full_name'] as String? ?? '',
      tenantName: tenant?['name'] as String?,
      role: data['role'] as String?,
      needsWorkspace: data['needs_workspace'] as bool? ?? tenant == null,
      subscription: sub != null ? SubscriptionInfo.fromJson(sub) : null,
      authMethods: AuthMethods.fromJson(data['auth_methods'] as Map<String, dynamic>?),
    );
  }
}

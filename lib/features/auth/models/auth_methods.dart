class AuthMethods {
  const AuthMethods({required this.hasPassword, required this.hasGoogle});

  final bool hasPassword;
  final bool hasGoogle;

  factory AuthMethods.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AuthMethods(hasPassword: false, hasGoogle: false);
    }
    return AuthMethods(
      hasPassword: json['has_password'] as bool? ?? false,
      hasGoogle: json['has_google'] as bool? ?? false,
    );
  }

  AuthMethods copyWith({bool? hasPassword, bool? hasGoogle}) {
    return AuthMethods(
      hasPassword: hasPassword ?? this.hasPassword,
      hasGoogle: hasGoogle ?? this.hasGoogle,
    );
  }
}

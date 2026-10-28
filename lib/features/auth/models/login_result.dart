import 'package:spy_love/features/auth/models/auth_user.dart';

/// Outcome of password login — either a full session or a 2FA challenge.
sealed class LoginResult {
  const LoginResult();
}

final class LoginSuccess extends LoginResult {
  const LoginSuccess(this.user);
  final AuthUser user;
}

final class LoginRequires2fa extends LoginResult {
  const LoginRequires2fa({required this.preAuthToken, this.email = ''});
  final String preAuthToken;
  final String email;
}

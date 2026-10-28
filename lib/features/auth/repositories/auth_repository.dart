import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/auth/google_sign_in_service.dart';

import 'package:spy_love/core/constants/api_constants.dart';

import 'package:spy_love/core/network/api_service.dart';

import 'package:spy_love/core/network/http_method.dart';

import 'package:spy_love/core/storage/token_storage.dart';

import 'package:spy_love/features/auth/models/auth_methods.dart';

import 'package:spy_love/features/auth/models/auth_user.dart';
import 'package:spy_love/features/auth/models/login_result.dart';
import 'package:spy_love/features/auth/models/totp_models.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokenStorage, this._googleSignIn);

  final ApiService _api;

  final TokenStorage _tokenStorage;

  final GoogleSignInService _googleSignIn;

  Future<Either<AuthUser, String>> register({
    required String email,

    required String password,

    required String fullName,

    required String tenantName,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.authRegister,

      method: HttpMethod.post,

      body: {
        'email': email,

        'password': password,

        'full_name': fullName,

        'tenant_name': tenantName,
      },

      requireAuth: false,

      loader: true,

      resultOverlay: true,
    );

    if (result.isLeft) {
      await _saveTokens(result.left);

      return Left(AuthUser.fromAuthResponse(result.left));
    }

    return Right(result.right);
  }

  Future<Either<LoginResult, String>> login({
    required String email,
    required String password,
    String deviceLabel = '',
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      if (deviceLabel.isNotEmpty) 'device_label': deviceLabel,
    };
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.authLogin,
      method: HttpMethod.post,
      body: body,
      requireAuth: false,
      loader: true,
      resultOverlay: true,
    );

    if (result.isLeft) {
      final data = result.left;
      if (data['requires_2fa'] == true) {
        final user = data['user'] as Map<String, dynamic>?;
        return Left(
          LoginRequires2fa(
            preAuthToken: data['pre_auth_token'] as String? ?? '',
            email: user?['email'] as String? ?? email,
          ),
        );
      }
      await _saveTokens(data);
      return Left(LoginSuccess(AuthUser.fromAuthResponse(data)));
    }

    return Right(result.right);
  }

  Future<Either<AuthUser, String>> verifyTotpLogin({
    required String preAuthToken,
    required String code,
    String deviceLabel = '',
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.auth2faVerify,
      method: HttpMethod.post,
      body: {
        'pre_auth_token': preAuthToken,
        'code': code.trim(),
        if (deviceLabel.isNotEmpty) 'device_label': deviceLabel,
      },
      requireAuth: false,
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) {
      await _saveTokens(result.left);
      return Left(AuthUser.fromAuthResponse(result.left));
    }
    return Right(result.right);
  }

  Future<Either<TotpStatus, String>> totpStatus() async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.auth2faStatus,
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );
    if (result.isLeft) return Left(TotpStatus.fromJson(result.left));
    return Right(result.right);
  }

  Future<Either<TotpEnrollment, String>> totpEnroll() async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.auth2faEnroll,
      method: HttpMethod.post,
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) return Left(TotpEnrollment.fromJson(result.left));
    return Right(result.right);
  }

  Future<Either<List<String>, String>> totpConfirm(String code) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.auth2faConfirm,
      method: HttpMethod.post,
      body: {'code': code.trim()},
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) {
      final codes = result.left['recovery_codes'] as List<dynamic>? ?? const [];
      return Left(codes.map((e) => e.toString()).toList());
    }
    return Right(result.right);
  }

  Future<Either<bool, String>> totpDisable({
    String? password,
    String? code,
  }) async {
    final body = <String, dynamic>{};
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (code != null && code.isNotEmpty) body['code'] = code.trim();
    final result = await _api.send<dynamic>(
      url: ApiConstants.auth2faDisable,
      method: HttpMethod.post,
      body: body,
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) return const Left(true);
    return Right(result.right);
  }

  Future<Either<List<String>, String>> totpRegenerateRecovery({
    String? password,
    String? code,
  }) async {
    final body = <String, dynamic>{};
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (code != null && code.isNotEmpty) body['code'] = code.trim();
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.auth2faRecovery,
      method: HttpMethod.post,
      body: body,
      loader: true,
      resultOverlay: true,
    );
    if (result.isLeft) {
      final codes = result.left['recovery_codes'] as List<dynamic>? ?? const [];
      return Left(codes.map((e) => e.toString()).toList());
    }
    return Right(result.right);
  }

  Future<Either<AuthUser, String>> signInWithGoogle({
    required String idToken,

    String? tenantName,

    String? fullName,
  }) async {
    final body = <String, dynamic>{'id_token': idToken};

    if (tenantName != null && tenantName.isNotEmpty) {
      body['tenant_name'] = tenantName;
    }

    if (fullName != null && fullName.isNotEmpty) {
      body['full_name'] = fullName;
    }

    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.authGoogle,

      method: HttpMethod.post,

      body: body,

      requireAuth: false,

      loader: true,

      resultOverlay: true,
    );

    if (result.isLeft) {
      await _saveTokens(result.left);

      return Left(AuthUser.fromAuthResponse(result.left));
    }

    if (_isTenantRequiredError(result.right)) {
      return const Right(ApiConstants.tenantRequiredError);
    }

    return Right(result.right);
  }

  Future<String?> obtainGoogleIdToken() => _googleSignIn.getIdToken();

  Future<Either<AuthMethods, String>> linkGoogle({
    required String idToken,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.authLinkGoogle,

      method: HttpMethod.post,

      body: {'id_token': idToken},

      loader: true,

      resultOverlay: true,
    );

    if (result.isLeft) {
      return Left(
        AuthMethods.fromJson(
          result.left['auth_methods'] as Map<String, dynamic>?,
        ),
      );
    }

    return Right(result.right);
  }

  Future<Either<AuthMethods, String>> setPassword({
    required String password,
  }) async {
    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.authSetPassword,

      method: HttpMethod.post,

      body: {'password': password},

      loader: true,

      resultOverlay: true,
    );

    if (result.isLeft) {
      return Left(
        AuthMethods.fromJson(
          result.left['auth_methods'] as Map<String, dynamic>?,
        ),
      );
    }

    return Right(result.right);
  }

  Future<Either<AuthUser?, String>> getCurrentUser() async {
    if (!await _tokenStorage.hasTokens()) {
      return const Left(null);
    }

    final result = await _api.send<Map<String, dynamic>>(
      url: ApiConstants.authMe,
      method: HttpMethod.get,
      loader: false,
      resultOverlay: false,
    );

    if (result.isLeft) {
      return Left(AuthUser.fromMeResponse(result.left));
    }

    // OneRequest already attempted a silent refresh on 401. Only wipe the
    // durable session when the failure is clearly unauthorized — never on
    // network / transient errors (that cleared tokens on every cold start).
    if (_isUnauthorizedError(result.right)) {
      await _tokenStorage.clearTokens();
      return const Left(null);
    }
    return Right(result.right);
  }

  bool _isUnauthorizedError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('not authenticated') ||
        lower.contains('authentication credentials') ||
        lower.contains('token_not_valid') ||
        lower.contains('token is invalid') ||
        lower.contains('token has expired') ||
        lower.contains('given token not valid') ||
        (lower.contains('refresh') && lower.contains('expired'));
  }

  Future<void> logout() async {
    final refresh = await _tokenStorage.getRefreshToken();

    if (refresh != null) {
      await _api.send<Map<String, dynamic>>(
        url: ApiConstants.authLogout,

        method: HttpMethod.post,

        body: {'refresh': refresh},

        loader: false,

        resultOverlay: false,
      );
    }

    await _tokenStorage.clearTokens();

    await _googleSignIn.signOut();
  }

  bool _isTenantRequiredError(String error) {
    final lower = error.toLowerCase();

    return lower.contains('tenant_required') ||
        lower.contains('organization name is required');
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final nested = data['tokens'] as Map<String, dynamic>?;
    final access = (nested?['access'] ?? data['access']) as String?;
    final refresh = (nested?['refresh'] ?? data['refresh']) as String?;
    if (access == null ||
        refresh == null ||
        access.isEmpty ||
        refresh.isEmpty) {
      throw StateError('Auth response missing access/refresh tokens');
    }
    await _tokenStorage.saveTokens(access: access, refresh: refresh);
  }
}

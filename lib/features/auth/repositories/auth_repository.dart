import 'package:spy_love/core/types/either.dart';
import 'package:spy_love/features/auth/google_sign_in_service.dart';

import 'package:spy_love/core/constants/api_constants.dart';

import 'package:spy_love/core/network/api_service.dart';

import 'package:spy_love/core/network/http_method.dart';

import 'package:spy_love/core/storage/token_storage.dart';

import 'package:spy_love/features/auth/models/auth_methods.dart';

import 'package:spy_love/features/auth/models/auth_user.dart';



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



  Future<Either<AuthUser, String>> login({

    required String email,

    required String password,

  }) async {

    final result = await _api.send<Map<String, dynamic>>(

      url: ApiConstants.authLogin,

      method: HttpMethod.post,

      body: {'email': email, 'password': password},

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



  Future<Either<AuthMethods, String>> linkGoogle({required String idToken}) async {

    final result = await _api.send<Map<String, dynamic>>(

      url: ApiConstants.authLinkGoogle,

      method: HttpMethod.post,

      body: {'id_token': idToken},

      loader: true,

      resultOverlay: true,

    );



    if (result.isLeft) {

      return Left(AuthMethods.fromJson(result.left['auth_methods'] as Map<String, dynamic>?));

    }

    return Right(result.right);

  }



  Future<Either<AuthMethods, String>> setPassword({required String password}) async {

    final result = await _api.send<Map<String, dynamic>>(

      url: ApiConstants.authSetPassword,

      method: HttpMethod.post,

      body: {'password': password},

      loader: true,

      resultOverlay: true,

    );



    if (result.isLeft) {

      return Left(AuthMethods.fromJson(result.left['auth_methods'] as Map<String, dynamic>?));

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

    await _tokenStorage.clearTokens();

    return const Left(null);

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

    final tokens = data['tokens'] as Map<String, dynamic>? ??

        {'access': data['access'], 'refresh': data['refresh']};

    await _tokenStorage.saveTokens(

      access: tokens['access'] as String,

      refresh: tokens['refresh'] as String,

    );

  }

}



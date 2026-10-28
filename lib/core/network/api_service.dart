import 'package:flutter/material.dart';
import 'package:one_request/one_request.dart' hide Either, Left, Right;
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/constants/api_constants.dart';
import 'package:spy_love/core/navigation/app_navigator.dart';
import 'package:spy_love/core/network/http_method.dart';
import 'package:spy_love/core/network/network_service.dart';
import 'package:spy_love/core/network/spy_request_chrome.dart';
import 'package:spy_love/core/storage/token_storage.dart';
import 'package:spy_love/core/types/either.dart';

class ApiService {
  ApiService(this._network, this._tokenStorage, this._overlay) {
    _bindAuth();
  }

  /// Per-service client. Shares the package Dio client, so [OneRequest.setAuth] still applies.
  final OneRequest _client = OneRequest(
    baseUrl: AppConfig.apiBaseUrl,
    headers: AppConfig.defaultHeaders,
  );
  final NetworkService _network;
  final TokenStorage _tokenStorage;
  final RequestOverlayController _overlay;

  void _bindAuth() {
    OneRequest.setAuth(
      getAccessToken: _tokenStorage.getAccessToken,
      getRefreshToken: _tokenStorage.getRefreshToken,
      saveTokens: (access, refresh) =>
          _tokenStorage.saveTokens(access: access, refresh: refresh),
      // Auth refresh posts this path on Dio directly, so it must already be absolute.
      refreshPath: _absolute(ApiConstants.authRefresh),
      skipPathContains: const [
        '/auth/login',
        '/auth/register',
        '/auth/google',
        '/auth/token',
      ],
      onRefreshFailed: _tokenStorage.clearTokens,
    );
  }

  static String _absolute(String path) {
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final tail = path.startsWith('/') ? path : '/$path';
    return '$base$tail';
  }

  Future<Either<T, String>> send<T>({
    required String url,
    required HttpMethod method,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? header,
    bool loader = true,
    bool resultOverlay = true,
    bool requireAuth = true,
    bool checkNetwork = true,
  }) async {
    if (checkNetwork) {
      final online = await _network.ensureConnected();
      if (!online) return const Right('No internet connection');
    }

    if (loader) _overlay.begin();
    try {
      final result = await _client.send<T>(
        url: url,
        method: _toRequestType(method),
        body: body,
        queryParameters: queryParameters,
        header: header,
        loader: false,
        resultOverlay: false,
      );

      final mapped = result.fold(
        ifRight: (data) => Left<T, String>(data),
        ifLeft: (error) {
          if (resultOverlay) {
            AppNavigator.snackbar(
              'Request failed',
              error,
              icon: Icons.error_outline,
            );
          }
          return Right<T, String>(error);
        },
      );
      return mapped;
    } finally {
      if (loader) _overlay.end();
    }
  }

  RequestType _toRequestType(HttpMethod method) => switch (method) {
    HttpMethod.get => RequestType.GET,
    HttpMethod.post => RequestType.POST,
    HttpMethod.put => RequestType.PUT,
    HttpMethod.delete => RequestType.DELETE,
    HttpMethod.patch => RequestType.PATCH,
  };
}

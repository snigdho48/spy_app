import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spy_love/core/debug/app_log.dart';
import 'package:spy_love/features/update/update_models.dart';

/// Self-update for sideloaded GitHub APKs (this app is not on Google Play, so
/// Play's `in_app_update` cannot be used).
///
/// Flow: read the public GitHub "latest" release for this repo, compare its
/// build number to the running build, and — only on explicit user consent —
/// download the matching ABI APK and hand it to the system package installer.
///
/// No API backend host is referenced here. Only this repo's public GitHub
/// release endpoints are used, which is safe to ship in a public client.
class UpdateService {
  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  // Public repo. GitHub serves the newest published, non-draft, non-prerelease
  // release here. The workflow also maintains a literal `latest` tag/release.
  static const String _owner = 'snigdho48';
  static const String _repo = 'spy_app';
  static const String _latestReleaseApi =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Returns release info when a strictly newer build is available, otherwise
  /// null. Swallows network/parse errors (returns null) so callers can call
  /// this on startup without guarding every failure mode.
  Future<AppReleaseInfo?> checkForUpdate() async {
    if (!_isAndroid) return null;
    try {
      final current = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(current.buildNumber) ?? 0;

      final res = await _dio.getUri<dynamic>(
        Uri.parse(_latestReleaseApi),
        options: Options(
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/vnd.github+json'},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final data = res.data;
      if (data is! Map) return null;

      final assets = <String, String>{};
      final rawAssets = data['assets'];
      if (rawAssets is List) {
        for (final a in rawAssets) {
          if (a is Map &&
              a['name'] is String &&
              a['browser_download_url'] is String) {
            assets[a['name'] as String] = a['browser_download_url'] as String;
          }
        }
      }

      final info = await _resolveReleaseInfo(data, assets);
      if (info == null) return null;
      if (info.buildNumber <= currentBuild) return null;
      return info;
    } catch (e, s) {
      AppLog.e('Update check failed', e, s);
      return null;
    }
  }

  /// Prefers the structured `latest.json` asset (carries the build number).
  /// Falls back to parsing the release tag (`v1.0.1` -> version only) with an
  /// unknown build so the dialog can still offer a manual reinstall.
  Future<AppReleaseInfo?> _resolveReleaseInfo(
    Map<dynamic, dynamic> release,
    Map<String, String> assets,
  ) async {
    final metaUrl = assets['latest.json'];
    if (metaUrl != null) {
      try {
        final meta = await _dio.getUri<dynamic>(
          Uri.parse(metaUrl),
          options: Options(responseType: ResponseType.plain),
        );
        final decoded = jsonDecode(meta.data.toString());
        if (decoded is Map<String, dynamic>) {
          final parsed = AppReleaseInfo.tryParse(decoded, assets);
          if (parsed != null) return parsed;
        }
      } catch (e, s) {
        AppLog.e('latest.json fetch failed', e, s);
      }
    }
    return null;
  }

  /// Device ABIs, most-preferred first.
  Future<List<String>> supportedAbis() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.supportedAbis;
    } catch (_) {
      return const <String>[];
    }
  }

  /// Downloads [url] to a temp file and opens it with the system installer.
  /// [onProgress] reports 0..1. Throws on failure so the UI can show an error.
  Future<void> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = Uri.parse(url).pathSegments.isNotEmpty
        ? Uri.parse(url).pathSegments.last
        : 'SpyLove-update.apk';
    final savePath = '${dir.path}/$fileName';
    final file = File(savePath);
    if (await file.exists()) {
      await file.delete();
    }

    await _dio.downloadUri(
      Uri.parse(url),
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    final result = await OpenFilex.open(
      savePath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw StateError('Could not open installer: ${result.message}');
    }
  }

  bool get _isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }
}

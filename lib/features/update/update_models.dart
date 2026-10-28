import 'package:spy_love/core/debug/app_log.dart';

/// Immutable description of the newest GitHub release build, parsed from the
/// `latest.json` asset attached to the release. The app backend is never
/// contacted here — only the public GitHub release for this repo.
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.buildNumber,
    required this.notes,
    required this.assets,
  });

  /// Semantic version name, e.g. `1.0.1`.
  final String version;

  /// Android versionCode / Flutter build number. Monotonic; drives the
  /// "is this newer than what I'm running" decision.
  final int buildNumber;

  /// Short, human release summary. Never contains API hosts.
  final String notes;

  /// Asset file name -> browser download URL, from the GitHub release.
  final Map<String, String> assets;

  /// Picks the download URL for the first supported ABI, falling back to the
  /// universal APK. [supportedAbis] is the device's `supportedAbis` list.
  String? apkUrlForAbis(List<String> supportedAbis) {
    for (final abi in supportedAbis) {
      final name = 'SpyLove-$abi.apk';
      final url = assets[name];
      if (url != null) return url;
    }
    return assets['SpyLove-universal.apk'];
  }

  static AppReleaseInfo? tryParse(
    Map<String, dynamic> latestJson,
    Map<String, String> assets,
  ) {
    try {
      final version = latestJson['version']?.toString();
      final rawBuild = latestJson['build'];
      final build = rawBuild is int
          ? rawBuild
          : int.tryParse(rawBuild?.toString() ?? '');
      if (version == null || version.isEmpty || build == null) return null;
      return AppReleaseInfo(
        version: version,
        buildNumber: build,
        notes: latestJson['notes']?.toString() ?? '',
        assets: assets,
      );
    } catch (e, s) {
      AppLog.e('Release info parse failed', e, s);
      return null;
    }
  }
}

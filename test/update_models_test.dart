import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/features/update/update_models.dart';

void main() {
  test('apkUrlForAbis prefers the first supported ABI then universal', () {
    const info = AppReleaseInfo(
      version: '1.0.1',
      buildNumber: 2,
      notes: '',
      assets: {
        'SpyLove-armeabi-v7a.apk': 'https://example.test/v7a.apk',
        'SpyLove-arm64-v8a.apk': 'https://example.test/arm64.apk',
        'SpyLove-universal.apk': 'https://example.test/uni.apk',
      },
    );
    expect(
      info.apkUrlForAbis(const ['arm64-v8a', 'armeabi-v7a']),
      'https://example.test/arm64.apk',
    );
    expect(
      info.apkUrlForAbis(const ['x86']),
      'https://example.test/uni.apk',
    );
  });

  test('tryParse requires version and build', () {
    expect(
      AppReleaseInfo.tryParse({'version': '1.0.1', 'build': 2}, const {}),
      isNotNull,
    );
    expect(AppReleaseInfo.tryParse({'version': '1.0.1'}, const {}), isNull);
  });
}

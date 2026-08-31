import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/infrastructure/update/models/app_update_info.dart';
import 'package:wznotes/infrastructure/update/update_service.dart';

void main() {
  group('UpdateService Version Detection Tests', () {
    test('Correctly detects newer semver versions', () {
      expect(
        UpdateService.isNewerVersion(
          remoteVersion: '0.8.0',
          remoteBuildNumber: 8,
          localVersion: '0.7.0',
          localBuildNumber: 7,
        ),
        isTrue,
      );

      expect(
        UpdateService.isNewerVersion(
          remoteVersion: '1.0.0',
          remoteBuildNumber: 10,
          localVersion: '0.7.0',
          localBuildNumber: 7,
        ),
        isTrue,
      );

      expect(
        UpdateService.isNewerVersion(
          remoteVersion: '0.7.1',
          remoteBuildNumber: 8,
          localVersion: '0.7.0',
          localBuildNumber: 7,
        ),
        isTrue,
      );
    });

    test('Correctly rejects older or equal versions', () {
      expect(
        UpdateService.isNewerVersion(
          remoteVersion: '0.7.0',
          remoteBuildNumber: 7,
          localVersion: '0.7.0',
          localBuildNumber: 7,
        ),
        isFalse,
      );

      expect(
        UpdateService.isNewerVersion(
          remoteVersion: '0.7.7',
          remoteBuildNumber: 14,
          localVersion: '0.7.7',
          localBuildNumber: 14,
        ),
        isFalse,
      );

      expect(
        UpdateService.isNewerVersion(
          remoteVersion: '0.6.9',
          remoteBuildNumber: 99,
          localVersion: '0.7.0',
          localBuildNumber: 7,
        ),
        isFalse,
      );
    });

    test('Correctly detects newer build numbers when semver is equal', () {
      expect(
        UpdateService.isNewerVersion(
          remoteVersion: '0.7.7',
          remoteBuildNumber: 15,
          localVersion: '0.7.7',
          localBuildNumber: 14,
        ),
        isTrue,
      );
    });

    test('Parses AppUpdateInfo JSON accurately', () {
      final jsonMap = {
        'version': '1.2.0',
        'build_number': 15,
        'title': 'Major Feature Update',
        'release_notes': '- New AMOLED themes\n- Fast Wi-Fi Sync',
        'windows_url': 'https://example.com/wznotes-win.zip',
        'android_url': 'https://example.com/wznotes.apk',
        'is_mandatory': true,
        'published_at': '2026-08-31T00:00:00Z',
      };

      final info = AppUpdateInfo.fromJson(jsonMap);

      expect(info.version, equals('1.2.0'));
      expect(info.buildNumber, equals(15));
      expect(info.title, equals('Major Feature Update'));
      expect(info.isMandatory, isTrue);
      expect(info.windowsUrl, equals('https://example.com/wznotes-win.zip'));
      expect(info.androidUrl, equals('https://example.com/wznotes.apk'));
    });
  });
}

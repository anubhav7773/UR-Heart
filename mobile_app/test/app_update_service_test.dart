import 'package:flutter_test/flutter_test.dart';
import 'package:ruralheart_mobile/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService Semantic Version Comparison Tests', () {
    test('cleanVersion strips prefix, build metadata, and prerelease tags', () {
      expect(AppUpdateService.cleanVersion('v1.1.0'), '1.1.0');
      expect(AppUpdateService.cleanVersion('V1.1.0+2'), '1.1.0');
      expect(AppUpdateService.cleanVersion('1.1.0-beta'), '1.1.0');
      expect(AppUpdateService.cleanVersion('v1.0.0-release+1'), '1.0.0');
      expect(AppUpdateService.cleanVersion(' 1.2.3 '), '1.2.3');
    });

    test('isServerVersionNewer returns false when versions are identical', () {
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '1.1.0',
          latestVersion: '1.1.0',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '1.1.0+2',
          latestVersion: '1.1.0',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: 'v1.1.0-beta',
          latestVersion: '1.1.0',
        ),
        isFalse,
      );
    });

    test('isServerVersionNewer returns false when installed version is newer than server', () {
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '1.2.0',
          latestVersion: '1.1.0',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '2.0.0',
          latestVersion: '1.1.0',
        ),
        isFalse,
      );
    });

    test('isServerVersionNewer returns true when server version is strictly newer', () {
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '1.0.0',
          latestVersion: '1.1.0',
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '1.1.0',
          latestVersion: '1.1.1',
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '1.1.0',
          latestVersion: '2.0.0',
        ),
        isTrue,
      );
    });

    test('isServerVersionNewer compares build number when major.minor.patch are equal', () {
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '1.1.0',
          latestVersion: '1.1.0',
          installedBuild: 1,
          latestBuild: 2,
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '1.1.0',
          latestVersion: '1.1.0',
          installedBuild: 2,
          latestBuild: 2,
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isServerVersionNewer(
          installedVersion: '1.1.0',
          latestVersion: '1.1.0',
          installedBuild: 3,
          latestBuild: 2,
        ),
        isFalse,
      );
    });
  });
}

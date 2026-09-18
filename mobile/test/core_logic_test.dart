import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

import 'package:ur_heart/core/security/installation_service.dart';
import 'package:ur_heart/core/utils/image_compressor.dart';
import 'package:ur_heart/features/ads/services/ad_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstallationService Sandbox Identity Tests', () {
    test('getOrCreateInstallationUuid returns valid UUID and persists across calls', () async {
      SharedPreferences.setMockInitialValues({});

      // 1. Initial generation
      final uuid1 = await InstallationService.getOrCreateInstallationUuid();
      expect(uuid1, isNotEmpty);
      expect(uuid1.length, 36);
      expect(
        RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(uuid1),
        isTrue,
      );

      // 2. Subsequent call returns identical persisted UUID
      final uuid2 = await InstallationService.getOrCreateInstallationUuid();
      expect(uuid2, equals(uuid1));

      // 3. Simulating app data clear / reinstall: SharedPreferences wiped
      SharedPreferences.setMockInitialValues({});
      final uuid3 = await InstallationService.getOrCreateInstallationUuid();
      expect(uuid3, isNotEmpty);
      expect(uuid3, isNot(equals(uuid1))); // New installation UUID generated
    });
  });

  group('ImageOptimizer BlurHash Benchmark Tests', () {
    test('generateBlurHashFromBytes returns valid BlurHash string from synthetic image', () {
      // Create synthetic 64x64 test image
      final testImage = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          testImage.setPixelRgba(x, y, 255, 46, 99, 255); // Crimson
        }
      }
      final pngBytes = Uint8List.fromList(img.encodePng(testImage));

      final blurHash = ImageOptimizer.generateBlurHashFromBytes(pngBytes);
      expect(blurHash, isNotEmpty);
      expect(blurHash.length, greaterThanOrEqualTo(6));
    });

    test('generateBlurHashFromBytes returns safe fallback on invalid bytes', () {
      final invalidBytes = Uint8List.fromList([0, 1, 2, 3]);
      final blurHash = ImageOptimizer.generateBlurHashFromBytes(invalidBytes);
      expect(blurHash, equals(ImageOptimizer.fallbackBlurHash));
    });
  });

  group('AdManager SSV Custom Data Specification Tests', () {
    test('formatSsvCustomData strictly matches {userId}:{adType}:{targetId} format', () {
      const userId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
      const targetId = 'f1e2d3c4-b5a6-7890-1234-56789abcdef0';

      // 1. Direct DM Reward
      final customDataDm = AdManager.formatSsvCustomData(
        userId: userId,
        adType: 'direct_dm_reward',
        targetId: targetId,
      );
      expect(customDataDm, equals('$userId:direct_dm_reward:$targetId'));
      expect(
        RegExp(r'^[0-9a-fA-F-]{36}:(direct_dm_reward|whatsapp_reveal):[0-9a-fA-F-]{36}$')
            .hasMatch(customDataDm),
        isTrue,
      );

      // 2. WhatsApp Reveal
      final customDataWa = AdManager.formatSsvCustomData(
        userId: userId,
        adType: 'whatsapp_reveal',
        targetId: targetId,
      );
      expect(customDataWa, equals('$userId:whatsapp_reveal:$targetId'));
      expect(
        RegExp(r'^[0-9a-fA-F-]{36}:(direct_dm_reward|whatsapp_reveal):[0-9a-fA-F-]{36}$')
            .hasMatch(customDataWa),
        isTrue,
      );
    });

    test('AdManager provides valid default Google AdMob test unit IDs', () {
      final adManager = AdManager.instance;
      expect(adManager.rewardedUnitId, isNotEmpty);
      expect(adManager.interstitialUnitId, isNotEmpty);
      expect(adManager.rewardedUnitId, startsWith('ca-app-pub-'));
      expect(adManager.interstitialUnitId, startsWith('ca-app-pub-'));
      expect(adManager.isRewardedAdReady, isFalse);
      expect(adManager.isInterstitialAdReady, isFalse);
    });
  });
}

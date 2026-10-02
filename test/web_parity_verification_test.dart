import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ur_heart/core/ads/rewarded_ad_manager.dart';
import 'package:ur_heart/core/ads/web_mindful_sponsor_dialog.dart';
import 'package:ur_heart/core/media/sanctuary_image_resolver.dart';
import 'package:ur_heart/features/growth/data/slumber_sensor_service.dart';
import 'package:ur_heart/features/profile_setup/presentation/widgets/live_kyc_recording_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Web vs Mobile Parity Subsystem Verification Tests', () {
    test('1. SanctuaryImageResolver resolves Web blob URLs, data URIs and assets', () {
      // Web Blob URL
      final blobProvider = resolveSanctuaryImageProvider('blob:http://localhost:3000/12345');
      expect(blobProvider, isNotNull);
      expect(blobProvider is NetworkImage, isTrue);

      // Web Base64 Data URI
      final sampleB64 = base64Encode(utf8.encode('test-image-bytes'));
      final dataUriProvider = resolveSanctuaryImageProvider('data:image/jpeg;base64,$sampleB64');
      expect(dataUriProvider, isNotNull);
      expect(dataUriProvider is MemoryImage, isTrue);

      // Asset URL
      final assetProvider = resolveSanctuaryImageProvider('assets/icon/app_icon.png');
      expect(assetProvider, isNotNull);
      expect(assetProvider is AssetImage, isTrue);
    });

    test('2. SlumberSensorService starts & stops safely on web without hardware sensor errors', () {
      final service = SlumberSensorService.instance;
      expect(() => service.startHardwareMonitoring(), returnsNormally);
      expect(service.isMonitoring, isTrue);

      // Web stillness session
      service.startWebStillnessSession();
      service.completeWebStillnessSession();

      expect(() => service.stopHardwareMonitoring(), returnsNormally);
      expect(service.isMonitoring, isFalse);
    });

    test('3. RewardedAdManager can be reset and configured without crashing', () {
      final adManager = RewardedAdManager.instance;
      expect(() => adManager.resetAndPreload(), returnsNormally);
      expect(adManager.canPlayAd(), isTrue);
    });

    testWidgets('4. WebMindfulSponsorDialog renders mindful reflection and countdown timer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebMindfulSponsorDialog(adType: 'quick_reflection'),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('SANCTUARY REFLECTION'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Claim Sanctuary Token ➔'), findsNothing); // Disabled during countdown
      expect(find.text('Reflecting...'), findsOneWidget);
    });

    testWidgets('5. LiveKycRecordingModal can be instantiated without dart:io fatal errors', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LiveKycRecordingModal(anchorPhotoBase64: ''),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Live Sanctuary Liveness Reflection'), findsOneWidget);
    });
  });
}

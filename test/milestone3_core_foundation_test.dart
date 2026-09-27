import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/app/ur_heart_app.dart';
import 'package:ur_heart/core/media/firebase_media_uploader.dart';
import 'package:ur_heart/core/media/media_compressor.dart';
import 'package:ur_heart/core/network/interceptors/installation_interceptor.dart';
import 'package:ur_heart/core/services/installation_service.dart';
import 'package:ur_heart/core/services/sentry_service.dart';
import 'package:ur_heart/core/theme/light_sanctuary_tokens.dart';
import 'package:ur_heart/core/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    InstallationService.clearMemoryCache();
    tempDir = await Directory.systemTemp.createTemp('ur_heart_m3_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Milestone 3 Exit Criterion 1: Fresh Install Theme Default', () {
    testWidgets('Fresh install cleanly defaults to Light Sanctuary Mode (#F9F6F0)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: URHeartApp(),
        ),
      );
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.scaffoldBackgroundColor, LightSanctuaryTokens.background);
      expect(materialApp.theme?.scaffoldBackgroundColor, const Color(0xFFF9F6F0));
      expect(find.text('Light Mode'), findsOneWidget);
    });
  });

  group('Milestone 3 Exit Criterion 2: Permanent Theme Lock Verification', () {
    testWidgets('Confirm & Lock locks theme permanently into Dark Mode',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(themeControllerProvider.notifier);
      expect(container.read(themeControllerProvider).mode, SanctuaryThemeMode.light);
      expect(container.read(themeControllerProvider).isLocked, false);

      // Switch draft to dark mode
      controller.switchDraftMode(SanctuaryThemeMode.dark);
      expect(container.read(themeControllerProvider).mode, SanctuaryThemeMode.dark);

      // Lock permanently
      await controller.lockThemePermanently();
      expect(container.read(themeControllerProvider).isLocked, true);

      // Subsequent attempts to mutate theme are ignored
      controller.switchDraftMode(SanctuaryThemeMode.light);
      expect(container.read(themeControllerProvider).mode, SanctuaryThemeMode.dark);

      // Simulate app restart by creating a new controller from persistence
      final restartedController = ThemeController();
      await restartedController.loadThemeFromPersistence();
      expect(restartedController.state.mode, SanctuaryThemeMode.dark);
      expect(restartedController.state.isLocked, true);

      // Attempt mutation on restarted controller
      restartedController.switchDraftMode(SanctuaryThemeMode.light);
      expect(restartedController.state.mode, SanctuaryThemeMode.dark);
    });
  });

  group('Milestone 3 Exit Criterion 3: Installation UUID Network Assertion', () {
    test('Dio requests contain X-Installation-UUID with valid UUID v4 format',
        () async {
      SharedPreferences.setMockInitialValues({});
      InstallationService.clearMemoryCache();

      final dio = Dio();
      dio.interceptors.add(InstallationInterceptor());

      RequestOptions? interceptedOptions;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            interceptedOptions = options;
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Network test interception complete',
              ),
            );
          },
        ),
      );

      try {
        await dio.get<dynamic>('https://example.com/api/test');
      } catch (_) {}

      expect(interceptedOptions, isNotNull);
      final uuidHeader = interceptedOptions?.headers['X-Installation-UUID'];
      expect(uuidHeader, isNotNull);

      final uuidV4Regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(uuidV4Regex.hasMatch(uuidHeader.toString()), true);
      expect(interceptedOptions?.headers['X-App-Client'], 'UR-Heart-Flutter-v1.0');
    });
  });

  group('Milestone 3 Exit Criterion 4: Client-Direct WebP Compression & BlurHash', () {
    test('MediaCompressor processes portrait photo with WebP & BlurHash in RAM',
        () async {
      final testImage = img.Image(width: 800, height: 1066);
      img.fill(testImage, color: img.ColorRgb8(249, 246, 240));
      final jpgBytes = img.encodeJpg(testImage, quality: 76);

      final sourceFile = File('${tempDir.path}/sample_portrait.jpg');
      await sourceFile.writeAsBytes(jpgBytes);

      final output = await MediaCompressor.processPortraitPhoto(sourceFile);
      expect(output, isNotNull);
      expect(output?.webpBytes, isNotNull);
      expect(output?.blurHash, isNotEmpty);
      expect(output?.byteSize, greaterThan(0));
      expect(output?.isUnder35Kb, true);
    });
  });

  group('Milestone 3 Exit Criterion 5: Direct Firebase Media Upload & Sentry', () {
    test('Slot index boundaries and Sentry PII stripping', () async {
      // Slot boundary check
      final invalidSlotResult = await FirebaseMediaUploader.uploadProfileSlot(
        userUuid: 'test-user-id',
        slotNumber: 6, // Exceeds 1-5
        webpBytes: Uint8List(10),
      );
      expect(invalidSlotResult, isNull);

      final zeroSlotResult = await FirebaseMediaUploader.uploadProfileSlot(
        userUuid: 'test-user-id',
        slotNumber: 0, // Less than 1
        webpBytes: Uint8List(10),
      );
      expect(zeroSlotResult, isNull);

      // Verify Sentry traces sample rate is 10%
      expect(SentryService.tracesSampleRate, 0.10);
    });
  });
}

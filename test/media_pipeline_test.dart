import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:ur_heart/core/media/media_compressor.dart';
import 'package:ur_heart/core/media/r2_uploader.dart';
import 'package:ur_heart/core/media/supabase_media_uploader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ur_heart_media_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 3 Exit Criterion 4: Media Compression & BlurHash', () {
    test('BlurHash generator produces valid non-empty string from image bytes', () {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(100, 150, 200));
      final pngBytes = img.encodePng(image);

      final blurHash = MediaCompressorService.extractBlurHashFromBytes(pngBytes);

      expect(blurHash, isNotEmpty);
      expect(blurHash.length, greaterThan(10));
    });

    test('MediaCompressorService produces file <100KB with valid BlurHash', () async {
      // Create a test image file
      final testImage = img.Image(width: 600, height: 800);
      img.fill(testImage, color: img.ColorRgb8(249, 247, 242));
      final rawBytes = img.encodeJpg(testImage, quality: 75);

      final sourceFile = File('${tempDir.path}/raw_photo.jpg');
      await sourceFile.writeAsBytes(rawBytes);

      final result = await MediaCompressorService.processProfilePhoto(
        sourceFile: sourceFile,
        slotNumber: 1,
        customTargetPath: '${tempDir.path}/processed_slot_1.webp',
      );

      expect(result, isNotNull);
      expect(result?.isUnder100Kb, true,
          reason: 'Compressed file size must be strictly under 100KB');
      expect(result?.blurHash, isNotEmpty,
          reason: 'BlurHash string must be non-empty');
      expect(result?.compressedFile.existsSync(), true);
    });

    test('R2Uploader executes direct HTTP PUT binary stream successfully', () async {
      final testFile = File('${tempDir.path}/test_upload.webp');
      await testFile.writeAsBytes(List.filled(5000, 42));

      String? capturedMethod;
      String? capturedContentType;
      int? capturedContentLength;

      final mockClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedContentType = request.headers['Content-Type'];
        capturedContentLength =
            int.tryParse(request.headers['Content-Length'] ?? '0');

        return http.Response('', 200);
      });

      final success = await R2Uploader.uploadBinaryToR2(
        presignedPutUrl: 'https://r2.cloudflarestorage.com/ur-heart-media/test.webp',
        fileToUpload: testFile,
        contentType: 'image/webp',
        customClient: mockClient,
      );

      expect(success, true);
      expect(capturedMethod, 'PUT');
      expect(capturedContentType, 'image/webp');
      expect(capturedContentLength, 5000);
    });

    test('SupabaseMediaUploader uploads successfully and enforces slot boundary (1-5)', () async {
      // Invalid slot checks
      final invalidSlot = await SupabaseMediaUploader.uploadProfileSlot(
        userUuid: 'test-uuid-1',
        slotNumber: 0,
        webpBytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(invalidSlot, isNull);

      final overSlot = await SupabaseMediaUploader.uploadProfileSlot(
        userUuid: 'test-uuid-1',
        slotNumber: 6,
        webpBytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(overSlot, isNull);

      // Valid upload with mock client
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['x-upsert'], 'true');
        expect(request.headers['Content-Type'], 'image/webp');
        return http.Response('{"Key": "ur-heart-media/test"}', 200);
      });

      SupabaseMediaUploader.setClientForTesting(mockClient);
      final url = await SupabaseMediaUploader.uploadProfileSlot(
        userUuid: 'test-uuid-1',
        slotNumber: 3,
        webpBytes: Uint8List.fromList([10, 20, 30]),
      );
      SupabaseMediaUploader.setClientForTesting(null);

      expect(url, isNotNull);
      expect(url, contains('ur-heart-media/users/test-uuid-1/moments/slot_3.webp'));
    });
  });
}

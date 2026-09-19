import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/image_normalizer.dart';
import '../../../core/utils/media_compressor.dart';

class PhotoUploadFlow {
  /// Normalizes EXIF orientation, validates via /scan-photo, and uploads photo
  static Future<void> processAndUpload({
    required File rawFile,
    required int slotIndex,
    bool requireFace = true,
  }) async {
    // 1. Client-side EXIF auto-rotation & downscaling
    final normalizedFile = await ImageNormalizer.normalizeAndCompress(rawFile);

    // 2. Compress & extract blurhash
    final compressed = await MediaCompressor.compressProfilePhoto(normalizedFile);

    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final dio = createApiClient();

    // 3. Moderation scan
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(compressed.bytes, filename: "slot_$slotIndex.webp"),
    });

    final scanRes = await dio.post(
      '/api/v1/moderation/scan-photo?require_face=$requireFace',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (scanRes.statusCode != 200) {
      throw Exception("Photo rejected by moderation filters.");
    }

    // 4. Upload to user photos repository
    final uploadData = FormData.fromMap({
      'slot_index': slotIndex,
      'blur_hash': compressed.blurHash,
      'file': MultipartFile.fromBytes(compressed.bytes, filename: "slot_$slotIndex.webp"),
    });

    await dio.post(
      '/api/v1/user/photos/upload',
      data: uploadData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}

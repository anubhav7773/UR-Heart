import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'supabase_media_uploader.dart';

/// Direct Client-to-Firebase Cloud Storage Media Uploader
/// Bypasses application backend entirely (0 MB Render server bandwidth)
class FirebaseMediaUploader {
  FirebaseMediaUploader._();

  static FirebaseStorage? _customStorage;

  static FirebaseStorage get _storage =>
      _customStorage ?? FirebaseStorage.instance;

  /// Allows mock injection in test environments
  static void setStorageInstanceForTesting(FirebaseStorage? storage) {
    _customStorage = storage;
  }

  /// Uploads compressed WebP direct to user moment slot (1 through 5)
  static Future<String?> uploadProfileSlot({
    required String userUuid,
    required int slotNumber,
    required Uint8List webpBytes,
    String? userName,
  }) async {
    if (slotNumber < 1 || slotNumber > 5) return null;

    final String folder;
    if (userName != null && userName.trim().isNotEmpty) {
      final safeName = userName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      folder = userUuid.startsWith(safeName) ? userUuid : '${safeName}_$userUuid';
    } else {
      folder = userUuid;
    }

    final String path = 'users/$folder/moments/slot_$slotNumber.webp';

    try {
      final Reference ref = _storage.ref().child(path);

      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/webp',
        cacheControl: 'public, max-age=2592000', // 30-Day Client Disk Cache
        customMetadata: {
          'slot_index': slotNumber.toString(),
          if (userName != null) 'user_name': userName,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );

      final UploadTask task = ref.putData(webpBytes, metadata);
      final TaskSnapshot snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      // Zero-Card Graceful Failover: Upload to Supabase Storage
      return await SupabaseMediaUploader.uploadProfileSlot(
        userUuid: userUuid,
        slotNumber: slotNumber,
        webpBytes: webpBytes,
        userName: userName,
      );
    }
  }
}

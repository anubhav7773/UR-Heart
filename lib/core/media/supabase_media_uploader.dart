import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../storage/secure_session_storage.dart';

/// Direct Client-to-Supabase Cloud Storage Media Uploader
/// Bypasses backend server completely (0 MB Render server bandwidth)
/// 100% Free with zero credit card required
class SupabaseMediaUploader {
  SupabaseMediaUploader._();

  static const String supabaseUrl = 'https://fmedkihgcvvzcekwybhe.supabase.co';
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtZWRraWhnY3Z2emNla3d5YmhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjU1NzEsImV4cCI6MjEwNTkwMTU3MX0.BKYfJW8rh-eP1fRdaEGmeELoS5s2aQpuIROpiRDgVFU',
  );
  static const String bucketName = 'ur-heart-media';

  static http.Client? _customClient;

  /// Allows mock injection in test environments
  static void setClientForTesting(http.Client? client) {
    _customClient = client;
  }

  /// Uploads compressed WebP direct to user moment slot (1 through 5)
  /// Incorporates user's name for identifiable and organized cloud storage
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
      if (!userUuid.startsWith(safeName)) {
        folder = '${safeName}_$userUuid';
      } else {
        folder = userUuid;
      }
    } else {
      folder = userUuid;
    }

    final String objectPath = 'users/$folder/moments/slot_$slotNumber.webp';
    final Uri uploadUri = Uri.parse(
      '$supabaseUrl/storage/v1/object/$bucketName/$objectPath',
    );

    final client = _customClient ?? http.Client();
    try {
      final userJwt = await SecureSessionStorage.instance.getAuthToken();
      final authHeader = (userJwt != null && userJwt.isNotEmpty) ? 'Bearer $userJwt' : 'Bearer $anonKey';

      final response = await client.post(
        uploadUri,
        headers: {
          'apikey': anonKey,
          'Authorization': authHeader,
          'Content-Type': 'image/webp',
          'x-upsert': 'true',
          'cache-control': 'public, max-age=2592000',
        },
        body: webpBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return '$supabaseUrl/storage/v1/object/public/$bucketName/$objectPath';
      }
      debugPrint('[SupabaseMediaUploader] Upload notice: status=${response.statusCode} body=${response.body}');
      return null;
    } catch (e) {
      debugPrint('[SupabaseMediaUploader] Upload exception: $e');
      return null;
    } finally {
      if (_customClient == null) {
        client.close();
      }
    }
  }

  /// Returns public CDN URL for a user moment slot
  static String getPublicUrl({
    required String userUuid,
    required int slotNumber,
    String? userName,
  }) {
    final String folder;
    if (userName != null && userName.trim().isNotEmpty) {
      final safeName = userName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      if (!userUuid.startsWith(safeName)) {
        folder = '${safeName}_$userUuid';
      } else {
        folder = userUuid;
      }
    } else {
      folder = userUuid;
    }
    final String objectPath = 'users/$folder/moments/slot_$slotNumber.webp';
    return '$supabaseUrl/storage/v1/object/public/$bucketName/$objectPath';
  }
}

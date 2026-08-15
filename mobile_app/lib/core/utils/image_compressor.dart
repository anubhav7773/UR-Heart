import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  /// Compresses camera or gallery photos before upload.
  /// - Downscales resolution to maximum 1080x1350 (portrait).
  /// - Sets quality to 80 JPEG to reduce 5-15MB photos down to < 300KB.
  /// - Compression takes < 300ms.
  /// - Falls back gracefully to original file if compression encounters any platform error.
  static Future<XFile> compressImage(XFile originalFile) async {
    try {
      final filePath = originalFile.path;
      final tempDir = await getTemporaryDirectory();
      final outPath =
          "${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg";

      final int originalBytes = await originalFile.length();
      final stopwatch = Stopwatch()..start();

      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        minWidth: 1080,
        minHeight: 1350,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      stopwatch.stop();

      if (compressed != null) {
        final int compressedBytes = await compressed.length();
        if (kDebugMode) {
          print(
            '[ImageCompressor] Compressed from ${(originalBytes / (1024 * 1024)).toStringAsFixed(2)} MB (${(originalBytes / 1024).toStringAsFixed(1)} KB) '
            'to ${(compressedBytes / 1024).toStringAsFixed(1)} KB in ${stopwatch.elapsedMilliseconds}ms.',
          );
        }
        return compressed;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ImageCompressor] Warning: Image compression error: $e. Using original.');
      }
    }
    return originalFile;
  }
}

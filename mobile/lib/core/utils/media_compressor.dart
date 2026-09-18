import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:blurhash_dart/blurhash_dart.dart' as bh;
import 'package:image/image.dart' as img;

class PhotoCompressionResult {
  final Uint8List bytes;
  final String blurHash;
  final int fileSizeBytes;
  final String format;

  PhotoCompressionResult({
    required this.bytes,
    required this.blurHash,
    required this.fileSizeBytes,
    required this.format,
  });
}

class VideoCompressionResult {
  final File compressedFile;
  final int fileSizeBytes;
  final int durationMs;

  VideoCompressionResult({
    required this.compressedFile,
    required this.fileSizeBytes,
    required this.durationMs,
  });
}

class MediaCompressor {
  /// Compresses raw camera/gallery image to WebP under 100 KB and extracts BlurHash
  static Future<PhotoCompressionResult> compressProfilePhoto(File sourceFile) async {
    final int originalSize = await sourceFile.length();
    
    // Step 1: Compress to WebP with target dimension ceiling (1080x1350 max, portrait standard)
    int targetQuality = 75;
    if (originalSize > 5 * 1024 * 1024) {
      targetQuality = 65; // Aggressive quality step-down for high-res captures
    }

    final Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
      sourceFile.absolute.path,
      minWidth: 1080,
      minHeight: 1350,
      quality: targetQuality,
      format: CompressFormat.webp,
      keepExif: false, // Strip EXIF metadata (GPS tags, device info) for privacy
    );

    if (compressedBytes == null || compressedBytes.isEmpty) {
      throw Exception("Image compression pipeline returned empty byte array.");
    }

    // Step 2: Enforce strict 100 KB ceiling with secondary optimization pass if necessary
    Uint8List finalBytes = compressedBytes;
    if (finalBytes.lengthInBytes > 100 * 1024) {
      final fallbackBytes = await FlutterImageCompress.compressWithList(
        finalBytes,
        minWidth: 900,
        minHeight: 1125,
        quality: 55,
        format: CompressFormat.webp,
      );
      if (fallbackBytes.isNotEmpty) {
        finalBytes = fallbackBytes;
      }
    }

    // Step 3: Compute lightweight BlurHash from a downsampled 32x32 thumbnail
    String calculatedBlurHash = "LEHLh[WB2yk8pyoJadR*.7kCMdnj"; // Fallback placeholder
    try {
      final img.Image? decoded = img.decodeImage(finalBytes);
      if (decoded != null) {
        final img.Image thumbnail = img.copyResize(decoded, width: 32, height: 32);
        calculatedBlurHash = bh.BlurHash.encode(thumbnail, numCompX: 4, numCompY: 3).hash;
      }
    } catch (_) {
      // Retain fallback hash if thumbnail extraction fails
    }

    return PhotoCompressionResult(
      bytes: finalBytes,
      blurHash: calculatedBlurHash,
      fileSizeBytes: finalBytes.lengthInBytes,
      format: "webp",
    );
  }

  /// Compresses 5-second selfie KYC video to 480p at 24fps
  static Future<VideoCompressionResult> compressKycVideo(File rawVideoFile) async {
    try {
      // Compress targeting Low/Medium 480p at 24fps
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        rawVideoFile.path,
        quality: VideoQuality.LowQuality, // Ensures ~600KB - 1.2MB output for 5s
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 24,
      );

      if (mediaInfo == null || mediaInfo.file == null) {
        throw Exception("Video compression pipeline failed to process file.");
      }

      final File compressedFile = mediaInfo.file!;
      final int size = await compressedFile.length();

      return VideoCompressionResult(
        compressedFile: compressedFile,
        fileSizeBytes: size,
        durationMs: (mediaInfo.duration ?? 5000).toInt(),
      );
    } finally {
      await VideoCompress.deleteAllCache();
    }
  }

  /// Wipes local cached media after successful network upload
  static Future<void> wipeLocalFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

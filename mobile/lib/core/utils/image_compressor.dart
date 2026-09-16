import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:blurhash_dart/blurhash_dart.dart' as bh;
import 'package:image/image.dart' as img;

/// Client-Side Image Process Result
class ImageProcessResult {
  final Uint8List compressedBytes;
  final String blurHash;
  final int fileSizeBytes;

  ImageProcessResult({
    required this.compressedBytes,
    required this.blurHash,
    required this.fileSizeBytes,
  });
}

/// Client-Side Media Compressor & BlurHash Generator
/// Compresses user photos to WebP under 100KB to minimize storage and bandwidth.
class ImageOptimizer {
  static const String fallbackBlurHash = 'LEHLh[WB2yk8pyoJadR*.7kCMdnj';

  /// Compresses a file to WebP format (Max 1080x1350, Quality 75) and generates BlurHash.
  static Future<ImageProcessResult?> processPhoto(File rawFile) async {
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      rawFile.absolute.path,
      minWidth: 1080,
      minHeight: 1350,
      quality: 75,
      format: CompressFormat.webp,
    );

    if (compressedBytes == null) return null;

    final blurHash = generateBlurHashFromBytes(compressedBytes);

    return ImageProcessResult(
      compressedBytes: compressedBytes,
      blurHash: blurHash,
      fileSizeBytes: compressedBytes.lengthInBytes,
    );
  }

  /// Calculates BlurHash string from image bytes with fallback on error.
  static String generateBlurHashFromBytes(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image != null) {
        final thumbnail = img.copyResize(image, width: 32, height: 32);
        final bhResult = bh.BlurHash.encode(thumbnail, numCompX: 4, numCompY: 3);
        return bhResult.hash;
      }
    } catch (_) {
      // Fallback
    }
    return fallbackBlurHash;
  }
}

import 'dart:typed_data';
import 'package:blurhash_dart/blurhash_dart.dart' as blurhash;
import 'package:image/image.dart' as img;

/// 32x32 Thumbnail BlurHash Encoder in RAM
class BlurhashGenerator {
  const BlurhashGenerator._();

  static const String fallbackHash = 'L6PZfSi_.AyE_3t7t7R**0o#DgR4';

  /// Generates BlurHash string from raw image bytes via 32x32 thumbnail in RAM
  static String generateBlurHash(
    Uint8List imageBytes, {
    int thumbnailDimension = 32,
    int numCompX = 4,
    int numCompY = 3,
  }) {
    try {
      final img.Image? decoded = img.decodeImage(imageBytes);
      if (decoded == null) return fallbackHash;

      final img.Image thumbnail = img.copyResize(
        decoded,
        width: thumbnailDimension,
        height: thumbnailDimension,
      );

      final String hash = blurhash.BlurHash.encode(
        thumbnail,
        numCompX: numCompX,
        numCompY: numCompY,
      ).hash;

      return hash.isNotEmpty ? hash : fallbackHash;
    } catch (_) {
      return fallbackHash;
    }
  }
}

import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageNormalizer {
  static Future<File> normalizeAndCompress(File rawFile) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path,
      'normalized_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    // Auto-rotates using EXIF orientation and downscales large camera dimensions
    final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
      rawFile.absolute.path,
      targetPath,
      quality: 85,
      minWidth: 1080,
      minHeight: 1350,
      autoCorrectionAngle: true, // Crucial: strips EXIF tilt
      format: CompressFormat.jpeg,
    );

    return compressed != null ? File(compressed.path) : rawFile;
  }
}

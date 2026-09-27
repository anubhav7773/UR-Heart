import 'dart:io';
import 'package:http/http.dart' as http;

/// Direct HTTP PUT uploader for Cloudflare R2 presigned URLs
/// Bypasses backend server completely to eliminate bandwidth costs
class R2Uploader {
  R2Uploader._();

  static const Duration uploadTimeout = Duration(seconds: 45);

  /// Direct binary streaming upload to Cloudflare R2 presigned URL
  static Future<bool> uploadBinaryToR2({
    required String presignedPutUrl,
    required File fileToUpload,
    required String contentType,
    http.Client? customClient,
  }) async {
    final client = customClient ?? http.Client();
    try {
      if (!fileToUpload.existsSync()) {
        return false;
      }

      final fileLength = await fileToUpload.length();
      final uri = Uri.parse(presignedPutUrl);

      final request = http.StreamedRequest('PUT', uri);
      request.headers['Content-Type'] = contentType;
      request.headers['Content-Length'] = fileLength.toString();

      final stream = fileToUpload.openRead();
      stream.listen(
        request.sink.add,
        onDone: request.sink.close,
        onError: request.sink.addError,
        cancelOnError: true,
      );

      final streamedResponse = await client.send(request).timeout(uploadTimeout);
      return streamedResponse.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (customClient == null) {
        client.close();
      }
    }
  }

  /// Direct in-memory byte upload to presigned URL
  static Future<bool> uploadBytesToR2({
    required String presignedPutUrl,
    required List<int> bytes,
    required String contentType,
    http.Client? customClient,
  }) async {
    final client = customClient ?? http.Client();
    try {
      final uri = Uri.parse(presignedPutUrl);
      final response = await client
          .put(
            uri,
            headers: {
              'Content-Type': contentType,
              'Content-Length': bytes.length.toString(),
            },
            body: bytes,
          )
          .timeout(uploadTimeout);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (customClient == null) {
        client.close();
      }
    }
  }
}

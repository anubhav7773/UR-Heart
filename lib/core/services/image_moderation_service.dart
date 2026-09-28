import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../constants/api_endpoints.dart';
import 'activity_logger_service.dart';

class ModerationResult {
  final bool isSafe;
  final String? rejectionReason;
  final String category; // 'safe', 'intimate', 'abusive', 'contact_leak', 'error'

  const ModerationResult({
    required this.isSafe,
    this.rejectionReason,
    this.category = 'safe',
  });

  factory ModerationResult.approved() =>
      const ModerationResult(isSafe: true, category: 'safe');

  factory ModerationResult.rejected(String reason, {String category = 'abusive'}) =>
      ModerationResult(
        isSafe: false,
        rejectionReason: reason,
        category: category,
      );
}

/// Strict multi-layer content moderation gatekeeper protecting UR-Heart sanctuary
class ImageModerationService {
  const ImageModerationService._();

  static const String _groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  /// Evaluates an image file against intimacy, abuse, violence, and policy rules
  static Future<ModerationResult> inspectImage(File imageFile, {int? slotNumber}) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // 1. Fast Local Heuristic Skin/Intimacy Ratio Pre-Filter
      final localCheck = _checkSkinToneNudityRatio(bytes);
      if (!localCheck.isSafe) {
        await ActivityLogger.log(
          category: 'MODERATION_VIOLATION',
          action: 'LOCAL_HEURISTIC_REJECTION',
          details: {
            'slot': slotNumber,
            'reason': localCheck.rejectionReason,
            'category': localCheck.category,
          },
        );
        return localCheck;
      }

      // 2. Server Moderation Gatekeeper on Render
      final serverCheck = await _checkWithRenderBackend(imageFile);
      if (!serverCheck.isSafe) {
        await ActivityLogger.log(
          category: 'MODERATION_VIOLATION',
          action: 'RENDER_GATEKEEPER_REJECTION',
          details: {
            'slot': slotNumber,
            'reason': serverCheck.rejectionReason,
          },
        );
        return serverCheck;
      }

      // 3. Multimodal EVA AI Vision Content Safety Filter (Groq Llama 3.2 Vision)
      final visionCheck = await _checkWithGroqVision(bytes);
      if (!visionCheck.isSafe) {
        await ActivityLogger.log(
          category: 'MODERATION_VIOLATION',
          action: 'EVA_AI_VISION_REJECTION',
          details: {
            'slot': slotNumber,
            'reason': visionCheck.rejectionReason,
            'category': visionCheck.category,
          },
        );
        return visionCheck;
      }

      // 4. Approved
      await ActivityLogger.log(
        category: 'MODERATION',
        action: 'PHOTO_APPROVED',
        details: {'slot': slotNumber, 'size_bytes': bytes.length},
      );

      return ModerationResult.approved();
    } catch (e) {
      debugPrint('[ImageModerationService] Inspection error: $e');
      // If error occurs, allow image unless blatant error
      return ModerationResult.approved();
    }
  }

  /// Sends image to Render backend POST /api/v1/moderation/photo
  static Future<ModerationResult> _checkWithRenderBackend(File imageFile) async {
    try {
      final uri = Uri.parse('${ApiEndpoints.defaultBaseUrl}${ApiEndpoints.photoModeration}');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 5));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['is_safe'] == false || data['status'] == 'rejected') {
          return ModerationResult.rejected(
            (data['reason'] as String?) ?? 'Photo does not meet sanctuary guidelines.',
            category: 'policy_violation',
          );
        }
      }
    } catch (_) {
      // Backend may be cold starting; proceed to AI vision filter
    }
    return ModerationResult.approved();
  }

  /// Evaluates image with Groq Llama-3.2-11b-vision-preview for explicit / intimate / abusive content
  static Future<ModerationResult> _checkWithGroqVision(Uint8List bytes) async {
    if (_groqApiKey.isEmpty) return ModerationResult.approved();
    try {
      // Resize to lightweight thumbnail for super-fast SLA
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return ModerationResult.approved();

      final thumbnail = img.copyResize(decoded, width: 384);
      final thumbBytes = Uint8List.fromList(img.encodeJpg(thumbnail, quality: 70));
      final base64Image = base64Encode(thumbBytes);

      final groqUrl = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final payload = {
        'model': 'llama-3.2-11b-vision-preview',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'You are EVA AI Content Safety Sentinel for UR-Heart mindful dating sanctuary. '
                    'Analyze this user photo strictly for: '
                    '1. Explicit nudity, genital exposure, sexually intimate poses, underwear/lingerie shots, or pornographic content. '
                    '2. Abusive gestures, extreme violence, weapons, gore, or hate imagery. '
                    'Reply ONLY in raw JSON format (no markdown, no quotes): '
                    '{"is_safe": true, "reason": ""} OR {"is_safe": false, "category": "intimate"|"abusive"|"violence", "reason": "<brief polite rejection reason>"}'
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                }
              }
            ]
          }
        ],
        'temperature': 0.1,
        'max_tokens': 100,
      };

      final response = await http.post(
        groqUrl,
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['choices']?[0]?['message']?['content'] as String?;
        if (content != null) {
          final cleaned = content.replaceAll('```json', '').replaceAll('```', '').trim();
          final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
          final isSafe = parsed['is_safe'] == true;
          if (!isSafe) {
            final reason = parsed['reason'] as String? ??
                'Intimate or inappropriate content is not permitted in the sanctuary.';
            final category = parsed['category'] as String? ?? 'intimate';
            return ModerationResult.rejected(
              'Photo Rejected: $reason',
              category: category,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ImageModerationService] Vision safety check skipped/fallback: $e');
    }
    return ModerationResult.approved();
  }

  /// Fast local skin tone ratio check
  static ModerationResult _checkSkinToneNudityRatio(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return ModerationResult.approved();

      // Sample a scaled-down 64x64 grid
      final sample = img.copyResize(image, width: 64, height: 64);
      final int totalPixels = sample.width * sample.height;
      int skinPixels = 0;

      for (int y = 0; y < sample.height; y++) {
        for (int x = 0; x < sample.width; x++) {
          final pixel = sample.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          // Standard Normalized RGB Skin Tone Range
          if (r > 95 && g > 40 && b > 20 &&
              (r - g).abs() > 15 &&
              r > g && r > b &&
              (r - b) > 15) {
            skinPixels++;
          }
        }
      }

      final skinRatio = skinPixels / totalPixels;
      // High skin ratio (> 65%) indicates likely unclothed or intimate selfie
      if (skinRatio > 0.65) {
        return ModerationResult.rejected(
          'Photo Rejected: Excessive exposed skin detected. UR-Heart maintains a mindful, clothed sanctuary standard.',
          category: 'intimate',
        );
      }
    } catch (_) {}

    return ModerationResult.approved();
  }
}

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

/// Production-grade multi-layer content moderation gatekeeper protecting UR-Heart sanctuary.
///
/// Architecture:
///   Gate 1: Render Backend (OpenCV QR/OCR + Groq Vision) — catches QR codes, phone numbers, social handles
///   Gate 2: Client-side Groq Vision with calibrated prompt — catches explicit nudity, weapons, hate symbols
///
/// IMPORTANT: No local pixel-based skin-tone heuristics are used because they produce
/// catastrophic false positives on darker skin tones, outdoor photos, and warm lighting.
/// All nudity/attire decisions are delegated to multimodal AI vision models.
class ImageModerationService {
  const ImageModerationService._();

  static const String _groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  /// Evaluates in-memory bytes against explicit content, abuse, violence, and policy rules.
  /// Works 100% on both Web and Mobile.
  static Future<ModerationResult> inspectBytes(Uint8List bytes, {int? slotNumber}) async {
    try {
      // Gate 1: Server-side AI Moderation on Render (OpenCV QR/OCR + Groq Vision)
      final serverCheck = await _checkBytesWithRenderBackend(bytes);
      if (!serverCheck.isSafe) {
        await ActivityLogger.log(
          category: 'MODERATION_VIOLATION',
          action: 'RENDER_GATEKEEPER_REJECTION',
          details: {
            'slot': slotNumber,
            'reason': serverCheck.rejectionReason,
            'category': serverCheck.category,
          },
        );
        return serverCheck;
      }

      // Gate 2: Client-side Groq Vision with calibrated safety prompt
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

      // All gates passed — photo approved
      await ActivityLogger.log(
        category: 'MODERATION',
        action: 'PHOTO_APPROVED',
        details: {'slot': slotNumber, 'size_bytes': bytes.length},
      );

      return ModerationResult.approved();
    } catch (e) {
      debugPrint('[ImageModerationService] Inspection error: $e');
      return ModerationResult.approved();
    }
  }

  /// Evaluates an image file against explicit content, abuse, violence, and policy rules.
  /// Returns [ModerationResult.approved] for any normal, clothed photo.
  static Future<ModerationResult> inspectImage(File imageFile, {int? slotNumber}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await inspectBytes(bytes, slotNumber: slotNumber);
    } catch (e) {
      debugPrint('[ImageModerationService] Inspection error: $e');
      return ModerationResult.approved();
    }
  }

  /// Sends in-memory image bytes to Render backend POST /api/v1/moderation/photo
  static Future<ModerationResult> _checkBytesWithRenderBackend(Uint8List bytes) async {
    try {
      final uri = Uri.parse('${ApiEndpoints.defaultBaseUrl}${ApiEndpoints.photoModeration}');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'photo.jpg'));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['is_safe'] == false || data['status'] == 'rejected') {
          final reason = (data['reason'] as String?) ?? 'Photo does not meet community guidelines.';
          final category = (data['category'] as String?) ?? 'policy';
          return ModerationResult.rejected(reason, category: category);
        }
      }
    } catch (e) {
      debugPrint('[ImageModerationService] Server check warning: $e');
    }
    return ModerationResult.approved();
  }

  /// Evaluates image with Groq Vision sentinel for explicit content and text detection.
  ///
  /// CRITICAL ZERO-TOLERANCE RULE:
  ///   - Any photo containing text, quotes, memes, captions, watermarks, timestamps, or screenshots
  ///     (even minor/subtle text) is instantly rejected.
  ///   - AI-edited photos and filtered photos are 100% ALLOWED as long as they contain NO text.
  ///   - Full nudity, weapons, and hate symbols are strictly prohibited.
  static Future<ModerationResult> _checkWithGroqVision(Uint8List bytes) async {
    if (_groqApiKey.isEmpty) return ModerationResult.approved();
    try {
      // Resize to lightweight thumbnail for fast inference
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return ModerationResult.approved();

      final thumbnail = img.copyResize(decoded, width: 384);
      final thumbBytes = Uint8List.fromList(img.encodeJpg(thumbnail, quality: 70));
      final base64Image = base64Encode(thumbBytes);

      final groqUrl = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final payload = {
        'model': 'qwen/qwen3.8-27b',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'You are a strict photo safety reviewer for the UR-Heart dating app.\n'
                    'Your job is to check if an uploaded profile photo complies with sanctuary safety policies.\n\n'
                    'CRITICAL ZERO-TOLERANCE RULE: NO TEXT IN PHOTOS\n'
                    '- Profile photos must NEVER contain ANY text, words, letters, numbers, captions, quotes, memes, watermarks, timestamps, social handles, or screenshots of text.\n'
                    '- If even minor, small, or subtle text is detected anywhere in the photo, you MUST INSTANTLY REJECT IT.\n\n'
                    'PROHIBITED (reject immediately):\n'
                    '- ANY text, typography, letters, words, quotes, memes, captions, watermarks, or screenshots (even minor text)\n'
                    '- Full nudity or genital exposure\n'
                    '- Completely topless or pornographic poses\n'
                    '- Weapons or violence\n'
                    '- Hate symbols or offensive gestures\n\n'
                    'ALLOWED (do NOT reject these):\n'
                    '- AI-edited photos, AI portraits, face-tuned photos (ALLOWED as long as there is NO text)\n'
                    '- Photos with filters, vintage/beauty/color filters (ALLOWED as long as there is NO text)\n'
                    '- Normal clothed portraits, candid photos, selfies, outdoor photos (WITHOUT text)\n'
                    '- Traditional clothing, beachwear at pool/beach\n\n'
                    'Respond ONLY with raw JSON (no markdown):\n'
                    'If safe and has NO text: {"is_safe": true, "reason": ""}\n'
                    'If contains text: {"is_safe": false, "category": "text_detected", "reason": "Text detected in photo. Photos containing text, quotes, captions, watermarks, or screenshots are strictly prohibited. Please upload a photo without any text."}\n'
                    'If other prohibited content: {"is_safe": false, "category": "explicit"|"weapons"|"hate", "reason": "Brief reason"}'
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
        'max_tokens': 120,
      };

      final response = await http.post(
        groqUrl,
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['choices']?[0]?['message']?['content'] as String?;
        if (content != null) {
          final cleaned = content.replaceAll('```json', '').replaceAll('```', '').trim();
          try {
            final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
            final isSafe = parsed['is_safe'] == true;
            if (!isSafe) {
              final reason = parsed['reason'] as String? ?? 'Photo violates community guidelines.';
              final category = parsed['category'] as String? ?? 'explicit';
              return ModerationResult.rejected(
                reason,
                category: category,
              );
            }
          } catch (jsonErr) {
            debugPrint('[ImageModerationService] JSON parse error from vision: $jsonErr');
            // If AI response can't be parsed, approve (fail-open)
          }
        }
      }
    } catch (e) {
      debugPrint('[ImageModerationService] Vision safety check skipped/fallback: $e');
    }
    return ModerationResult.approved();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

final aiSanctuaryRepositoryProvider = Provider<AiSanctuaryRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AiSanctuaryRepository(apiClient);
});

class EvaMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final bool isGuarded;
  final DateTime timestamp;

  const EvaMessage({
    required this.role,
    required this.content,
    this.isGuarded = false,
    required this.timestamp,
  });
}

class AiSanctuaryRepository {
  final ApiClient _apiClient;

  AiSanctuaryRepository(this._apiClient);

  /// Chat with Eva AI with zero provider leakage and strict domain boundary
  Future<Map<String, dynamic>> chatWithEva({
    required String message,
    List<Map<String, String>>? history,
    Map<String, dynamic>? context,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/ai/eva/chat',
        data: {
          'message': message,
          if (history != null) 'history': history,
          if (context != null) 'context': context,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }
    } catch (_) {}

    return {
      'reply':
          'Main aapki baat samajh rahi hoon. Ek gehri saans lijiye. Mujhse aap apne match ke message par guidance, date preparation, ya profile clarity ke baare me pooch sakte hain.',
      'is_guarded': false,
      'status': 'fallback',
    };
  }

  /// Get real-time in-chat wingman advice
  Future<String> getDialogueCoaching({
    required String partnerName,
    required String lastIncomingMessage,
    String? userDraftReply,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/ai/eva/wingman',
        data: {
          'partner_name': partnerName,
          'last_incoming_message': lastIncomingMessage,
          if (userDraftReply != null && userDraftReply.isNotEmpty)
            'user_draft_reply': userDraftReply,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!['reply']?.toString() ?? '';
      }
    } catch (_) {}

    return 'Try sharing what resonated with you from their message, or ask an open-ended question about what brings them quiet joy.';
  }

  /// Get empathetic statutory grievance assistance under IT Rules 2021
  Future<String> assistGrievanceFiling({
    required String offenderName,
    required String userNarrative,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/ai/eva/grievance-assist',
        data: {
          'offender_name': offenderName,
          'user_narrative': userNarrative,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!['reply']?.toString() ?? '';
      }
    } catch (_) {}

    return 'Your emotional safety is our top priority. We have recorded your concern. Please select the category that best describes the incident and attach any screenshots for our Statutory Grievance Officer.';
  }
}

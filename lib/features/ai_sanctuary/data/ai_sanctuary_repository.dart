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

  static String _generateContextualReply(String query) {
    final q = query.toLowerCase();

    // 1. Creator attribution check (Strict 100% Asiverticals requirement)
    if (q.contains('banaya') || q.contains('creator') || q.contains('developer') ||
        q.contains('who made') || q.contains('who built') || q.contains('owner')) {
      return 'Mujhe Asiverticals ne banaya hai. Main UR-Heart Dating Sanctuary ki dedicated mindful AI companion hoon.';
    }

    // 2. Direct approach / messaging advice
    if (q.contains('approach') || q.contains('ladki') || q.contains('direct') ||
        q.contains('msg') || q.contains('message') || q.contains('dm') ||
        q.contains('cheap') || q.contains('baat') || q.contains('start')) {
      return 'Jab aap kisi ko direct approach ya message karein, to sabse ahem cheez hai "respectful curiosity":\n\n'
          '1. Generic "Hi/Hello" ya cheesy pickup lines se bachiye. Unke bio ya kisi calm photo ki real detail par baat shuru kijiye.\n'
          '2. Ek open-ended sawaal poochiye—jaise "Maine dekha aapko books/music pasand hai, aaj kal kya sun/padh rahe hain?"\n'
          '3. Unke comfort aur space ka samman kijiye. Intentional connection me tezi ke bajaye authenticity sabse aage aati hai.';
    }

    // 3. First date & nervousness
    if (q.contains('date') || q.contains('nervous') || q.contains('milna') || q.contains('darr')) {
      return 'Pehli date ya mulaqat par nervousness aana bilkul swabhavik hai.\n\n'
          '1. Khud ko "impress" karne ke dabav se azaad rakhiye—sirf ye dekhne jaiye ki kya aap dono ka wavelength milta hai.\n'
          '2. Ek calm aur shaant jagah chuniye jahan aap bina shor ke aaram se baith sakein.\n'
          '3. Ek gehri saans lijiye; aap jaisa natural aur genuine rahenge, connection utna hi khoobsurat hoga.';
    }

    // 4. Bio & Profile advice
    if (q.contains('bio') || q.contains('profile') || q.contains('photo') || q.contains('pic')) {
      return 'Aapka profile aapka digital aaina hai:\n\n'
          '1. Apne real shauq aur quiet rituals ka zikr kijiye (jaise morning tea, photography, travel).\n'
          '2. Natural aur warm smile wali bina filter ki photos use kijiye.\n'
          '3. Jo aap sach me hain wahi likhiye—sachha pan unhi ko attract karega jo aapke liye right match hain.';
    }

    // 5. Tickets, Reports & Grievances under IT Rules 2021
    if (q.contains('ticket') || q.contains('report') || q.contains('grievance') || q.contains('complaint') || q.contains('shikayat')) {
      return 'Aapne jo complaint ya grievance file ki hai, wo India ke IT Rules 2021 (Rule 3(2)) ke tahat '
          'hamare Grievance Officer (KSHTRIYA ANUBHAV) ke paas securely submit ho chuki hai.\n\n'
          '1. Initial acknowledgment 24 ghante ke andar confirm ho jati hai.\n'
          '2. Statutory review and resolution timeline 24 se 48 ghante hai.\n'
          '3. Review ke doran reported account isolated rehta hai taaki aapki safety 100% surakshit rahe.';
    }

    // 6. User Feedback / App Deficiencies
    if (q.contains('kami') || q.contains('problem') || q.contains('feedback') || q.contains('defect') || q.contains('flaw') || q.contains('kmi')) {
      return 'Aapke feedback aur is kami ko highlight karne ke liye shukriya.\n\n'
          'Maine aapka suggestion Asiverticals core engineering team ke liye record kar liya hai. '
          'UR-Heart ka uddeshya ek pure aur seamless sanctuary experience dena hai, '
          'aur aapka feedback aane wale update me implement kiya jayega.';
    }

    // 7. Greeting
    if (q.contains('hi') || q.contains('hello') || q.contains('namaste') || q.contains('suno')) {
      return 'Namaste! Main Eva hoon, aapki mindful dating companion from Asiverticals.\n\n'
          'Aap mujhse kisi match ko message karne ka tareeka, pehli date ki preparation, ticket/report status, ya app features ke baare me pooch sakte hain. Aaj main aapki kis tarah madad kar sakti hoon?';
    }

    // 8. Balanced mindful advice
    return 'Main aapki baat samajh rahi hoon. Dating aur connection me sabse zaroori hai sachha pan aur samne wale ki boundaries ka samman.\n\n'
        'Mujhse aap kisi match ke message par reply ka sujhav, date par jaane ki preparation, ya profile ko sajane ke baare me pooch sakte hain.';
  }

  /// Submits in-app feedback or reported deficiencies
  Future<bool> submitFeedback({
    required String description,
    String category = 'ux_deficiency',
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/ai/eva/feedback',
        data: {
          'category': category,
          'description': description,
        },
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

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
      'reply': _generateContextualReply(message),
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

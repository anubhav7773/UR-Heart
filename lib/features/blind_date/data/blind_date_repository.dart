import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../domain/blind_date_models.dart';

final blindDateRepositoryProvider = Provider<BlindDateRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BlindDateRepository(apiClient);
});

class BlindDateRepository {
  final ApiClient _apiClient;

  BlindDateRepository(this._apiClient);

  Future<BlindDateEligibility> getEligibility() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/api/v1/blind-date/eligibility',
    );
    return BlindDateEligibility.fromJson(response.data ?? {});
  }

  Future<BlindDateEligibility> claimAdPass() async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/blind-date/claim-ad-pass',
    );
    return BlindDateEligibility.fromJson(response.data ?? {});
  }

  Future<Map<String, dynamic>> joinQueue({bool isFastTrack = false}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/blind-date/queue/join',
      data: {'is_fast_track': isFastTrack},
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> extendSession(String sessionId) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/blind-date/session/$sessionId/extend',
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> checkQueueStatus() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/api/v1/blind-date/queue/status',
    );
    return response.data ?? {};
  }

  Future<bool> cancelQueue() async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/blind-date/queue/cancel',
    );
    return response.data?['success'] as bool? ?? false;
  }

  Future<BlindDateSessionModel> getSession(String sessionId) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/api/v1/blind-date/session/$sessionId',
    );
    return BlindDateSessionModel.fromJson(response.data ?? {});
  }

  Future<BlindDateMessageModel> sendMessage(
      String sessionId, String ciphertext) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/blind-date/session/$sessionId/message',
      data: {'ciphertext': ciphertext},
    );
    return BlindDateMessageModel.fromJson(response.data ?? {});
  }

  Future<List<BlindDateMessageModel>> getMessages(String sessionId) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/api/v1/blind-date/session/$sessionId/messages',
    );
    final data = response.data ?? [];
    return data
        .map((item) =>
            BlindDateMessageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BlindDateSessionModel> submitDecision(
      String sessionId, String decision) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/blind-date/session/$sessionId/resonate',
      data: {'decision': decision},
    );
    // Combine session response with session model
    final data = response.data ?? {};
    return BlindDateSessionModel(
      id: sessionId,
      status: data['status'] as String? ?? 'active',
      myDecision: data['my_decision'] as String? ?? decision,
      matchId: data['match_id'] as String?,
      partner: data['partner'] != null
          ? BlindDatePartner.fromJson(data['partner'] as Map<String, dynamic>)
          : null,
    );
  }
}

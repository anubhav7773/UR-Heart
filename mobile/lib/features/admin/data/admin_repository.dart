import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/network/api_client.dart';

class KycStatsModel {
  final int pending;
  final int verified;
  final int rejected;

  KycStatsModel({required this.pending, required this.verified, required this.rejected});

  factory KycStatsModel.fromJson(Map<String, dynamic> json) {
    return KycStatsModel(
      pending: json['pending_count'] ?? 0,
      verified: json['verified_count'] ?? 0,
      rejected: json['rejected_count'] ?? 0,
    );
  }
}

class KycCandidateModel {
  final int queueId;
  final String userId;
  final String registeredName;
  final String registeredCity;
  final String transcript;
  final double confidenceScore;
  final List<String> flags;
  final String videoPlaybackUrl;
  final DateTime createdAt;

  KycCandidateModel({
    required this.queueId,
    required this.userId,
    required this.registeredName,
    required this.registeredCity,
    required this.transcript,
    required this.confidenceScore,
    required this.flags,
    required this.videoPlaybackUrl,
    required this.createdAt,
  });

  factory KycCandidateModel.fromJson(Map<String, dynamic> json) {
    return KycCandidateModel(
      queueId: json['queue_id'],
      userId: json['user_id'],
      registeredName: json['registered_name'] ?? 'Unknown',
      registeredCity: json['registered_city'] ?? 'Unknown',
      transcript: json['extracted_transcript'] ?? '',
      confidenceScore: (json['ai_confidence_score'] as num?)?.toDouble() ?? 0.0,
      flags: List<String>.from(json['ai_flags'] ?? []),
      videoPlaybackUrl: json['video_playback_url'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class AdminRepository {
  final Dio _dio;

  AdminRepository({Dio? dio}) : _dio = dio ?? createApiClient();

  Future<Options> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<KycStatsModel> fetchStats() async {
    final response = await _dio.get('/api/v1/admin/kyc/stats', options: await _authHeaders());
    return KycStatsModel.fromJson(response.data);
  }

  Future<List<KycCandidateModel>> fetchQueue() async {
    final response = await _dio.get('/api/v1/admin/kyc/queue', options: await _authHeaders());
    return (response.data as List).map((e) => KycCandidateModel.fromJson(e)).toList();
  }

  Future<void> submitDecision({
    required int queueId,
    required String userId,
    required String decision, // 'approve' | 'reject'
    String? rejectionReason,
  }) async {
    await _dio.post(
      '/api/v1/admin/kyc/review-decision',
      data: {
        'queue_id': queueId,
        'user_id': userId,
        'decision': decision,
        'rejection_reason': rejectionReason,
      },
      options: await _authHeaders(),
    );
  }
}

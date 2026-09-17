import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/network/api_client.dart';

class MatchItemModel {
  final String matchId;
  final String partnerId;
  final String partnerName;
  final String partnerPhotoUrl;
  final String partnerCity;
  final String partnerBio;
  final bool whatsappUnlocked;
  final String? lastMessage;
  final DateTime createdAt;

  MatchItemModel({
    required this.matchId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerPhotoUrl,
    required this.partnerCity,
    required this.partnerBio,
    required this.whatsappUnlocked,
    this.lastMessage,
    required this.createdAt,
  });

  factory MatchItemModel.fromJson(Map<String, dynamic> json) {
    return MatchItemModel(
      matchId: json['match_id'] as String? ?? '',
      partnerId: json['partner_id'] as String? ?? '',
      partnerName: json['partner_name'] as String? ?? 'Match Partner',
      partnerPhotoUrl: json['partner_photo_url'] as String? ?? '',
      partnerCity: json['partner_city'] as String? ?? 'Lucknow',
      partnerBio: json['partner_bio'] as String? ?? '',
      whatsappUnlocked: json['whatsapp_unlocked'] as bool? ?? false,
      lastMessage: json['last_message'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class MatchesRepository {
  final Dio _client;

  MatchesRepository({Dio? client})
      : _client = client ?? createApiClient(baseUrl: EnvConfig.apiBaseUrl);

  /// Fetch active matches for the authenticated user from GET /api/v1/chat/matches
  Future<List<MatchItemModel>> getMatches() async {
    try {
      final response = await _client.get('/api/v1/chat/matches');
      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List<dynamic>;
        return list
            .map((item) => MatchItemModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('MatchesRepository.getMatches error: $e');
      return [];
    }
  }
}

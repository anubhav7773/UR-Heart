import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';

class WalletBalanceModel {
  final int dmCredits;
  final int waRevealTokens;
  final int missedBioPasses;
  final int streakShields;
  final int totalAdsWatched;
  final int nightFarmAdsToday;
  final bool canFarmTonight;

  WalletBalanceModel({
    required this.dmCredits,
    required this.waRevealTokens,
    required this.missedBioPasses,
    required this.streakShields,
    required this.totalAdsWatched,
    required this.nightFarmAdsToday,
    required this.canFarmTonight,
  });

  factory WalletBalanceModel.fromJson(Map<String, dynamic> json) {
    return WalletBalanceModel(
      dmCredits: json['dm_credits'] ?? 0,
      waRevealTokens: json['wa_reveal_tokens'] ?? 0,
      missedBioPasses: json['missed_bio_passes'] ?? 0,
      streakShields: json['streak_shields'] ?? 0,
      totalAdsWatched: json['total_ads_watched'] ?? 0,
      nightFarmAdsToday: json['night_farm_ads_today'] ?? 0,
      canFarmTonight: json['can_farm_tonight'] ?? true,
    );
  }
}

class WalletRepository {
  final Dio _dio;

  WalletRepository({Dio? dio}) : _dio = dio ?? createApiClient();

  Future<Options> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<WalletBalanceModel> fetchBalance() async {
    final response = await _dio.get('/api/v1/wallet/balance', options: await _authHeaders());
    return WalletBalanceModel.fromJson(response.data);
  }

  Future<bool> spendCredit({required String rewardType, int amount = 1, String? targetId}) async {
    try {
      final response = await _dio.post(
        '/api/v1/wallet/spend',
        data: {
          'reward_type': rewardType,
          'amount': amount,
          'target_id': targetId,
        },
        options: await _authHeaders(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        return false; // Insufficient credits
      }
      rethrow;
    }
  }

  Future<void> claimReward({
    required String adTier,
    required String rewardChoice,
  }) async {
    final idempotencyKey = "claim_${const Uuid().v4()}";
    await _dio.post(
      '/api/v1/wallet/claim-reward',
      data: {
        'ad_tier': adTier,
        'reward_choice': rewardChoice,
        'idempotency_key': idempotencyKey,
      },
      options: await _authHeaders(),
    );
  }
}

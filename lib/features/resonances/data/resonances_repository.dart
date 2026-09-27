import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Entity representing an incoming like from another sanctuary user
class IncomingLike {
  final String id;
  final String senderId;
  final String fullName;
  final int age;
  final String photoUrl;
  final String blurHash;
  final String relativeTime;
  final String sharedInterest;
  final int matchScore;

  const IncomingLike({
    required this.id,
    required this.senderId,
    required this.fullName,
    required this.age,
    required this.photoUrl,
    required this.blurHash,
    required this.relativeTime,
    required this.sharedInterest,
    this.matchScore = 92,
  });
}

/// Entity representing an established mutual match
class MutualConnection {
  final String id;
  final String matchId;
  final String partnerId;
  final String fullName;
  final int age;
  final String photoUrl;
  final String blurHash;
  final String matchedTime;
  final String lastSnippet;
  final bool hasUnreadMessages;
  final bool isOnline;

  const MutualConnection({
    required this.id,
    required this.matchId,
    required this.partnerId,
    required this.fullName,
    required this.age,
    required this.photoUrl,
    required this.blurHash,
    required this.matchedTime,
    required this.lastSnippet,
    this.hasUnreadMessages = false,
    this.isOnline = true,
  });
}

/// Repository fetching incoming likes and established mutual dialogues
class ResonancesRepository {
  final ApiClient? _apiClient;

  ResonancesRepository([this._apiClient]);

  Future<List<IncomingLike>> fetchIncomingLikes() async {
    final client = _apiClient;
    if (client == null) {
      return _mockIncomingLikes();
    }
    try {
      final res = await client.dio.get<List<dynamic>>('/api/v1/resonances/incoming');
      final data = res.data;
      if (data != null) {
        return data.map((json) {
          final map = json as Map<String, dynamic>;
          return IncomingLike(
            id: map['id'] as String? ?? 'like_1',
            senderId: map['sender_id'] as String? ?? 'user_1',
            fullName: map['full_name'] as String? ?? 'Aarav Mehta',
            age: map['age'] as int? ?? 26,
            photoUrl: map['photo_url'] as String? ?? '',
            blurHash: map['blur_hash'] as String? ?? 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
            relativeTime: map['relative_time'] as String? ?? '10m ago',
            sharedInterest: map['shared_interest'] as String? ?? 'Architecture & Solitude',
            matchScore: map['match_score'] as int? ?? 94,
          );
        }).toList();
      }
      return _mockIncomingLikes();
    } catch (_) {
      return _mockIncomingLikes();
    }
  }

  Future<List<MutualConnection>> fetchMutualConnections() async {
    final client = _apiClient;
    if (client == null) {
      return _mockMutualConnections();
    }
    try {
      final res = await client.dio.get<List<dynamic>>('/api/v1/resonances/mutual');
      final data = res.data;
      if (data != null) {
        return data.map((json) {
          final map = json as Map<String, dynamic>;
          return MutualConnection(
            id: map['id'] as String? ?? 'conn_1',
            matchId: map['match_id'] as String? ?? 'match_1',
            partnerId: map['partner_id'] as String? ?? 'p_1',
            fullName: map['full_name'] as String? ?? 'Kabir Singh',
            age: map['age'] as int? ?? 27,
            photoUrl: map['photo_url'] as String? ?? '',
            blurHash: map['blur_hash'] as String? ?? 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
            matchedTime: map['matched_time'] as String? ?? 'Yesterday',
            lastSnippet: map['last_snippet'] as String? ?? 'Looking forward to our coffee discussion.',
            hasUnreadMessages: map['has_unread'] as bool? ?? true,
            isOnline: map['is_online'] as bool? ?? true,
          );
        }).toList();
      }
      return _mockMutualConnections();
    } catch (_) {
      return _mockMutualConnections();
    }
  }

  Future<bool> createMutualMatch(String senderId) async {
    final client = _apiClient;
    if (client == null) return true;
    try {
      final res = await client.dio.post<Map<String, dynamic>>(
        '/api/v1/swipes',
        data: {'target_id': senderId, 'swipe_type': 'like'},
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return true;
    }
  }

  List<IncomingLike> _mockIncomingLikes() {
    return const [
      IncomingLike(
        id: 'like_1',
        senderId: 'user_aarav',
        fullName: 'Aarav Mehta',
        age: 26,
        photoUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
        blurHash: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
        relativeTime: '10m ago',
        sharedInterest: 'Architecture & Slow Living',
        matchScore: 94,
      ),
      IncomingLike(
        id: 'like_2',
        senderId: 'user_rohan',
        fullName: 'Rohan Varma',
        age: 28,
        photoUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
        blurHash: 'L5H2EC=~00Rj~pRP%2of%2j[00WB',
        relativeTime: '1h ago',
        sharedInterest: 'Analog Film & Pour-Over Coffee',
        matchScore: 89,
      ),
    ];
  }

  List<MutualConnection> _mockMutualConnections() {
    return const [
      MutualConnection(
        id: 'conn_1',
        matchId: 'match_101',
        partnerId: 'user_neha',
        fullName: 'Neha Bose',
        age: 25,
        photoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        blurHash: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
        matchedTime: '2 hours ago',
        lastSnippet: 'I loved that passage by Haruki Murakami.',
        hasUnreadMessages: true,
        isOnline: true,
      ),
    ];
  }
}

final resonancesRepositoryProvider = Provider<ResonancesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ResonancesRepository(apiClient);
});

import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../features/chat/chat_screen.dart';
import '../features/profile/profile_view_dialog.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _liked = [];
  List<Map<String, dynamic>> _disliked = [];

  @override
  void initState() {
    super.initState();
    _fetchActivityData();
  }

  Future<void> _fetchActivityData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.instance.dio.get('/users/activity');
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        setState(() {
          _matches = (data['matches'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _liked = (data['liked'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _disliked = (data['disliked'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load activity: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openProfileDialog(Map<String, dynamic> user) {
    final photos = (user['photos'] as List<dynamic>? ?? [])
        .map((p) => p.toString())
        .where((p) => p.isNotEmpty)
        .toList();

    showDialog<void>(
      context: context,
      builder: (_) => ProfileViewDialog(
        name: (user['full_name'] ?? user['first_name'] ?? 'User').toString(),
        age: (user['age'] as num?)?.toInt() ?? 0,
        distanceLabel: (user['area_name'] ?? 'Nearby').toString(),
        photos: photos,
        isVerified: user['is_verified'] == true,
      ),
    );
  }

  void _openChatScreen(String matchId, Map<String, dynamic> user) {
    final photos = (user['photos'] as List<dynamic>? ?? []);
    final avatar = photos.isNotEmpty ? photos.first.toString() : '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          matchId: matchId,
          recipientUser: ChatRecipient(
            id: user['id']?.toString() ?? '',
            name: user['full_name']?.toString() ?? 'User',
            avatarUrl: avatar,
            isVerified: user['is_verified'] == true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.grey[950],
          elevation: 0,
          title: const Text('Activity & Swipes', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: const Color(0xFFE91E63),
            indicatorWeight: 3,
            labelColor: const Color(0xFFE91E63),
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite, size: 16),
                    const SizedBox(width: 6),
                    Text('Matches (${_matches.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.thumb_up_alt_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('Liked (${_liked.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.close, size: 16),
                    const SizedBox(width: 6),
                    Text('Passed (${_disliked.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _fetchActivityData,
          color: const Color(0xFFE91E63),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchActivityData,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
                            child: const Text('Retry', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      children: [
                        _buildMatchesTab(),
                        _buildSwipeListTab(_liked, isLiked: true),
                        _buildSwipeListTab(_disliked, isLiked: false),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildMatchesTab() {
    if (_matches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border,
        title: 'No Matches Yet',
        subtitle: 'Keep exploring and swiping to find your mutual match!',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final matchItem = _matches[index];
        final matchId = matchItem['match_id']?.toString() ?? '';
        final user = matchItem['user'] as Map<String, dynamic>? ?? {};
        final name = user['full_name'] ?? 'User';
        final age = user['age'];
        final photos = user['photos'] as List<dynamic>? ?? [];
        final photoUrl = photos.isNotEmpty ? photos.first.toString() : '';
        final bool isVerified = user['is_verified'] == true;

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[800]!),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _openProfileDialog(user),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, size: 50, color: Colors.grey)),
                            )
                          : const Center(child: Icon(Icons.person, size: 50, color: Colors.grey)),
                      if (isVerified)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.verified, color: Colors.blue, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    Text(
                      age != null ? '$name, $age' : name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: () => _openChatScreen(matchId, user),
                        icon: const Icon(Icons.chat_bubble_outline, size: 14),
                        label: const Text('Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwipeListTab(List<Map<String, dynamic>> items, {required bool isLiked}) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: isLiked ? Icons.thumb_up_alt_outlined : Icons.close,
        title: isLiked ? 'No Likes Recorded' : 'No Passes Recorded',
        subtitle: isLiked
            ? 'People you like on the feed will appear here.'
            : 'People you swipe left on will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final user = item['user'] as Map<String, dynamic>? ?? {};
        final name = user['full_name'] ?? 'User';
        final age = user['age'];
        final area = user['area_name'] ?? '';
        final photos = user['photos'] as List<dynamic>? ?? [];
        final photoUrl = photos.isNotEmpty ? photos.first.toString() : '';
        final bool isVerified = user['is_verified'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _openProfileDialog(user),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          age != null ? '$name, $age' : name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blue, size: 16),
                        ],
                      ],
                    ),
                    if (area.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(area, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _openProfileDialog(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isLiked ? const Color(0xFFE91E63) : Colors.grey,
                  side: BorderSide(color: isLiked ? const Color(0xFFE91E63) : Colors.grey[700]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('View', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

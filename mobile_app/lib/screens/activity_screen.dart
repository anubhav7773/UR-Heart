import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
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
        backgroundColor: AppTheme.surface_root,
        appBar: AppBar(
          backgroundColor: AppTheme.surface_root,
          elevation: 0,
          title: const Text('Activity & Swipes', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: AppTheme.accent_primary,
            indicatorWeight: 3,
            labelColor: AppTheme.accent_primary,
            unselectedLabelColor: AppTheme.text_secondary,
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
          color: AppTheme.accent_primary,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accent_primary))
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.status_destructive, size: 48),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: const TextStyle(color: AppTheme.text_secondary)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchActivityData,
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent_primary),
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
        childAspectRatio: 0.69,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final matchItem = _matches[index];
        final matchId = matchItem['match_id']?.toString() ?? '';
        final user = matchItem['user'] as Map<String, dynamic>? ?? {};
        final name = user['full_name'] ?? user['first_name'] ?? 'User';
        final age = user['age'];
        final photos = user['photos'] as List<dynamic>? ?? [];
        final photoUrl = photos.isNotEmpty ? photos.first.toString() : '';
        final bool isVerified = user['is_verified'] == true;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface_card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border_subtle),
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
                      // Candidate Photo
                      photoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 350,
                              memCacheHeight: 450,
                              placeholder: (_, __) => Container(
                                color: AppTheme.surface_interactive,
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppTheme.accent_primary, strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.surface_interactive,
                                child: const Center(child: Icon(Icons.person, size: 50, color: AppTheme.text_tertiary)),
                              ),
                            )
                          : Container(
                              color: AppTheme.surface_interactive,
                              child: const Center(child: Icon(Icons.person, size: 50, color: AppTheme.text_tertiary)),
                            ),

                      // Bottom Dark Gradient Overlay for High Contrast
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.4, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Top-Right Glassmorphic Verified Shield
                      if (isVerified)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0x8C000000),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.accent_verified_blue.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: AppTheme.accent_verified_blue,
                              size: 16,
                            ),
                          ),
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
                      age != null ? '$name, $age' : '$name',
                      style: const TextStyle(
                        color: AppTheme.text_primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3366), Color(0xFFFF5E7E)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openChatScreen(matchId, user),
                          borderRadius: BorderRadius.circular(10),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Message',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
        final name = user['full_name'] ?? user['first_name'] ?? 'User';
        final age = user['age'];
        final area = user['area_name'] ?? '';
        final photos = user['photos'] as List<dynamic>? ?? [];
        final photoUrl = photos.isNotEmpty ? photos.first.toString() : '';
        final bool isVerified = user['is_verified'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface_card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border_subtle),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _openProfileDialog(user),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: ClipOval(
                    child: photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 112,
                            memCacheHeight: 112,
                            placeholder: (_, __) => Container(color: AppTheme.surface_interactive),
                            errorWidget: (_, __, ___) => Container(
                              color: AppTheme.surface_interactive,
                              child: const Icon(Icons.person, color: AppTheme.text_tertiary),
                            ),
                          )
                        : Container(
                            color: AppTheme.surface_interactive,
                            child: const Icon(Icons.person, color: AppTheme.text_tertiary),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            age != null ? '$name, $age' : '$name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.text_primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppTheme.accent_verified_blue, size: 16),
                        ],
                      ],
                    ),
                    if (area.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(area, style: const TextStyle(color: AppTheme.text_secondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _openProfileDialog(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isLiked ? AppTheme.accent_primary : AppTheme.text_secondary,
                  side: BorderSide(color: isLiked ? AppTheme.accent_primary : AppTheme.border_subtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface_card,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border_subtle),
              ),
              child: Icon(icon, size: 44, color: AppTheme.text_tertiary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.text_primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.text_secondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

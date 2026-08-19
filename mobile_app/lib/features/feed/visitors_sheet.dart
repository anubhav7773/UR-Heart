import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../chat/chat_screen.dart';

class ProfileVisitor {
  final String userId;
  final String name;
  final int age;
  final String city;
  final String? photoUrl;
  final List<String> photos;
  final double? distanceKm;
  final String distanceLabel;
  final String actionType;
  final bool isVerified;
  final String visitedAt;
  final String timeAgo;

  const ProfileVisitor({
    required this.userId,
    required this.name,
    required this.age,
    required this.city,
    this.photoUrl,
    this.photos = const [],
    this.distanceKm,
    this.distanceLabel = 'Nearby',
    this.actionType = 'pass',
    this.isVerified = false,
    required this.visitedAt,
    this.timeAgo = 'Recently',
  });

  factory ProfileVisitor.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? [];
    final List<String> parsedPhotos =
        rawPhotos.map((e) => e.toString()).toList();
    final String? pUrl = json['photo_url']?.toString() ??
        (parsedPhotos.isNotEmpty ? parsedPhotos.first : null);

    return ProfileVisitor(
      userId: (json['user_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['full_name'] ?? 'UR Heart User').toString(),
      age: (json['age'] as num?)?.toInt() ?? 22,
      city: (json['city'] ?? json['area_name'] ?? 'Ayodhya Region').toString(),
      photoUrl: pUrl,
      photos: parsedPhotos,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      distanceLabel: (json['distance_label'] ?? 'Nearby').toString(),
      actionType: (json['action_type'] ?? 'pass').toString(),
      isVerified: json['is_verified'] == true,
      visitedAt: (json['visited_at'] ?? '').toString(),
      timeAgo: (json['time_ago'] ?? 'Recently').toString(),
    );
  }
}

class VisitorsSheet extends StatefulWidget {
  final VoidCallback? onVisitorsUpdated;

  const VisitorsSheet({
    super.key,
    this.onVisitorsUpdated,
  });

  static Future<void> show({
    required BuildContext context,
    VoidCallback? onVisitorsUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VisitorsSheet(onVisitorsUpdated: onVisitorsUpdated),
    );
  }

  @override
  State<VisitorsSheet> createState() => _VisitorsSheetState();
}

class _VisitorsSheetState extends State<VisitorsSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ProfileVisitor> _visitors = [];
  int _totalCount = 0;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchVisitors();
  }

  Future<void> _fetchVisitors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.instance.getVisitors(limit: 50);
      if (res.data != null && res.data['data'] != null) {
        final data = res.data['data'];
        final rawList = data['visitors'] as List<dynamic>? ?? [];
        setState(() {
          _totalCount = (data['total_count'] as num?)?.toInt() ?? rawList.length;
          _visitors = rawList
              .map((e) =>
                  ProfileVisitor.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load profile visitors. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _dismissVisitor(ProfileVisitor visitor) async {
    final String vId = visitor.userId;
    setState(() {
      _visitors.removeWhere((v) => v.userId == vId);
      _totalCount = _visitors.length;
    });
    widget.onVisitorsUpdated?.call();

    try {
      await ApiClient.instance.dismissVisitor(visitorId: vId);
    } catch (_) {}
  }

  Future<void> _likeBackVisitor(ProfileVisitor visitor) async {
    final String vId = visitor.userId;
    setState(() => _processingIds.add(vId));

    try {
      final res = await ApiClient.instance.postMatchesSwipe(
        targetUserId: vId,
        action: 'like',
      );

      final isMatch = res.data?['data']?['is_match'] == true;
      final matchId = res.data?['data']?['match_id']?.toString();

      setState(() {
        _visitors.removeWhere((v) => v.userId == vId);
        _totalCount = _visitors.length;
      });
      widget.onVisitorsUpdated?.call();

      if (mounted) {
        if (isMatch && matchId != null && matchId.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 It\'s a Match with ${visitor.name}!'),
              backgroundColor: AppTheme.primaryColor,
              action: SnackBarAction(
                label: 'Chat Now',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        matchId: matchId,
                        recipientUser: ChatRecipient(
                          id: visitor.userId,
                          name: visitor.name,
                          avatarUrl: visitor.photoUrl ?? '',
                          isVerified: visitor.isVerified,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Liked ${visitor.name}! We will notify you on a match.'),
              backgroundColor: AppTheme.surfaceColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action notice: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(vId));
    }
  }

  Future<void> _unlockDirectDM(ProfileVisitor visitor) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFB800), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Color(0xFFFFB800), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Direct DM Pass • ₹49',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Skip the match queue and slide directly into ${visitor.name}\'s chat tray right now!',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorderColor),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Color(0xFFFFB800), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '1-Hour Instant Messaging Pass Included',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedTextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB800),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Pay ₹49 & Chat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final String vId = visitor.userId;
    setState(() => _processingIds.add(vId));

    try {
      final res =
          await ApiClient.instance.unlockDirectDMSachet(targetUserId: vId);

      if (res.data != null && res.data['data'] != null) {
        final data = res.data['data'];
        final String convId = (data['conversation_id'] ?? data['match_id'] ?? '')
            .toString();

        setState(() {
          _visitors.removeWhere((v) => v.userId == vId);
          _totalCount = _visitors.length;
        });
        widget.onVisitorsUpdated?.call();

        if (mounted) {
          Navigator.pop(context); // Close visitors sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                matchId: convId,
                recipientUser: ChatRecipient(
                  id: visitor.userId,
                  name: visitor.name,
                  avatarUrl: visitor.photoUrl ?? '',
                  isVerified: visitor.isVerified,
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment notice: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(vId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AppTheme.cardBorderColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mutedTextColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(Icons.visibility_outlined,
                          color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Who Passed You',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_totalCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$_totalCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'People who swiped or visited your deck recently',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: AppTheme.mutedTextColor),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppTheme.cardBorderColor, height: 1),

              // Visitors List / Empty View
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryColor),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 48,
                                      color: AppTheme.mutedTextColor),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppTheme.mutedTextColor,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchVisitors,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor),
                                    child: const Text('Retry',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _visitors.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: AppTheme.backgroundColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppTheme.cardBorderColor),
                                        ),
                                        child: const Icon(
                                            Icons.visibility_off_outlined,
                                            size: 48,
                                            color: AppTheme.mutedTextColor),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No Ghost Passers Yet!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'When nearby people view or pass your profile in the discovery deck, they will appear here for a second chance.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppTheme.mutedTextColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                itemCount: _visitors.length,
                                itemBuilder: (context, index) {
                                  final visitor = _visitors[index];
                                  return _buildVisitorCard(visitor);
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitorCard(ProfileVisitor visitor) {
    final bool isProcessing = _processingIds.contains(visitor.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Info, Time Tag
          Row(
            children: [
              // Avatar with fallback
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: visitor.photoUrl != null &&
                          visitor.photoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: visitor.photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.surfaceColor,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.surfaceColor,
                            child: const Icon(Icons.person,
                                color: AppTheme.mutedTextColor),
                          ),
                        )
                      : Container(
                          color: AppTheme.surfaceColor,
                          child: const Icon(Icons.person,
                              color: AppTheme.mutedTextColor),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Name, Age, Location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${visitor.name}, ${visitor.age}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (visitor.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 14, color: AppTheme.verifiedBlue),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${visitor.city} • ${visitor.distanceLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Time Ago Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 11, color: AppTheme.mutedTextColor),
                    const SizedBox(width: 3),
                    Text(
                      visitor.timeAgo,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.mutedTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Action Buttons: [ ✕ Dismiss ] [ ❤️ Like Back ] [ ⚡ Direct DM • ₹49 ]
          Row(
            children: [
              // Button 1: Dismiss
              IconButton(
                onPressed:
                    isProcessing ? null : () => _dismissVisitor(visitor),
                icon: const Icon(Icons.close, size: 18),
                color: AppTheme.mutedTextColor,
                tooltip: 'Dismiss',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppTheme.cardBorderColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Button 2: Like Back
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isProcessing ? null : () => _likeBackVisitor(visitor),
                  icon: const Icon(Icons.favorite_rounded,
                      size: 14, color: AppTheme.primaryColor),
                  label: const Text('Like Back',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.cardBorderColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Button 3: Direct DM • ₹49
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      isProcessing ? null : () => _unlockDirectDM(visitor),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.bolt_rounded,
                          size: 15, color: Colors.black),
                  label: const Text(
                    'DM • ₹49',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../chat/presentation/screens/chats_list_screen.dart';
import '../../../chat/presentation/screens/chat_dialogue_screen.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../profile/presentation/screens/my_persona_screen.dart';
import '../../../resonances/presentation/screens/resonances_screen.dart';
import '../../../rewards/presentation/screens/growth_hub_screen.dart';
import '../../../ai_sanctuary/presentation/screens/eva_sanctuary_screen.dart';
import '../../../../core/services/sanctuary_notification_service.dart';
import '../widgets/whatsapp_notification_banner.dart';

/// Global Navigation Index State Provider for Tab Switching
final navigationIndexProvider = StateProvider<int>((ref) => 0);

/// Sanctuary Navigation Shell hosting the 5 primary tabs:
/// 0: Feed (Discovery Deck)
/// 1: Resonances (Incoming Likes & Mutual Matches)
/// 2: Chats (Active Dialogues & Recent Sparks)
/// 3: Growth PRO (Mindful Ads, Slumber & Sovereign Pass)
/// 4: My Persona (Sanctuary Profile & Settings)
class SanctuaryNavigationShell extends ConsumerStatefulWidget {
  static const String routeName = '/main';
  final int initialIndex;

  const SanctuaryNavigationShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<SanctuaryNavigationShell> createState() =>
      _SanctuaryNavigationShellState();
}

class _SanctuaryNavigationShellState
    extends ConsumerState<SanctuaryNavigationShell> {
  DateTime? _lastBackPressTime;
  Timer? _notificationPoller;
  int _unreadResonanceCount = 0;
  int _unreadChatCount = 0;
  final Set<String> _seenNotificationIds = {};
  OverlayEntry? _activeNotificationOverlay;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('ur_heart_profile_setup_completed', true);
      prefs.setBool('ur_heart_has_entered_sanctuary', true);
      final storedSeen = prefs.getStringList('sanctuary_seen_notification_ids') ?? [];
      _seenNotificationIds.addAll(storedSeen);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex != 0) {
        ref.read(navigationIndexProvider.notifier).state = widget.initialIndex;
      }
      _startNotificationPoller();
    });
  }

  void _startNotificationPoller() {
    _pollNotifications();
    _notificationPoller = Timer.periodic(const Duration(seconds: 12), (_) {
      _pollNotifications();
    });
  }

  Future<void> _pollNotifications() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio
          .get<Map<String, dynamic>>('/api/v1/notifications');
      if (response.statusCode == 200 && response.data != null) {
        final notifications =
            response.data!['notifications'] as List<dynamic>? ?? [];
        final unreadList = notifications
            .cast<Map<String, dynamic>>()
            .where((n) =>
                n['is_read'] != true &&
                !_seenNotificationIds.contains(n['id']?.toString()))
            .toList();

        if (unreadList.isNotEmpty && mounted) {
          final isDark =
              ref.read(themeProvider).activeTheme == SanctuaryTheme.dark;
          // Mark all unread notifications as seen, dispatch to native tray, and acknowledge to backend
          for (final notif in unreadList) {
            final notifId = notif['id']?.toString();
            if (notifId != null) {
              _seenNotificationIds.add(notifId);
              // Acknowledge read to backend so it never delivers as unread on restart
              apiClient.dio.post<dynamic>(
                '/api/v1/notifications/mark-read',
                data: {'notification_id': notifId},
              ).ignore();
            }


            final nType = notif['type']?.toString().toLowerCase() ?? 'system';
            final nTitle = notif['title']?.toString() ?? 'Sanctuary Resonance';
            final nBody = notif['body']?.toString() ?? '';
            final nData = notif['data'] as Map<String, dynamic>? ?? {};

            try {
              if (nType.contains('message') || nType.contains('chat')) {
                final sName = nData['sender_name']?.toString() ??
                    nTitle.replaceAll('Message from ', '').replaceAll(' 💬', '').trim();
                final mId = nData['match_id']?.toString() ??
                    notif['match_id']?.toString() ??
                    'm_${DateTime.now().millisecondsSinceEpoch}';
                final sId = nData['sender_id']?.toString() ?? 'user_peer';
                SanctuaryNotificationService.instance.showDialogueMessageNotification(
                  senderName: sName,
                  messageText: nBody,
                  matchId: mId,
                  senderId: sId,
                );
              } else if (nType.contains('spark') || nType.contains('match')) {
                final pName = nData['peer_name']?.toString() ??
                    nData['partner_name']?.toString() ??
                    nTitle;
                final mId = nData['match_id']?.toString() ??
                    'm_${DateTime.now().millisecondsSinceEpoch}';
                final pId = nData['peer_id']?.toString() ??
                    nData['partner_id']?.toString() ??
                    'peer_1';
                SanctuaryNotificationService.instance.showMutualSparkNotification(
                  peerName: pName,
                  matchId: mId,
                  peerId: pId,
                );
              } else if (nType.contains('direct')) {
                final sName = nData['sender_name']?.toString() ?? 'Seeker';
                final mId = nData['match_id']?.toString() ??
                    'm_${DateTime.now().millisecondsSinceEpoch}';
                final sId = nData['sender_id']?.toString() ?? 'user_peer';
                SanctuaryNotificationService.instance.showDirectLetterNotification(
                  senderName: sName,
                  messageSnippet: nBody,
                  matchId: mId,
                  senderId: sId,
                );
              } else if (nType.contains('streak')) {
                final streakVal = nData['streak_count'] as int? ?? 1;
                SanctuaryNotificationService.instance.showStreakAlertNotification(
                  streakCount: streakVal,
                  hoursRemaining: 6,
                );
              } else {
                SanctuaryNotificationService.instance.showSystemNotification(
                  id: (notifId ?? 'notif').hashCode,
                  title: nTitle,
                  body: nBody,
                );
              }
            } catch (_) {}
          }

          // Show strictly only the single latest notification as an in-app banner
          final latestNotif = unreadList.last;
          _showWhatsAppNotification(latestNotif, isDark);

          // Persist seen IDs so on app kill and re-open, the same notification never pops again
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList(
                'sanctuary_seen_notification_ids', _seenNotificationIds.toList());
          } catch (_) {}

          setState(() {
            _unreadResonanceCount = notifications
                .where((n) => n['is_read'] != true && n['type'] != 'message')
                .length;
            _unreadChatCount = notifications
                .where((n) => n['is_read'] != true && n['type'] == 'message')
                .length;
          });
        }
      }
    } catch (_) {}
  }

  void _handleNotificationNavigation(Map<String, dynamic> notif) {
    if (!mounted) return;
    _dismissActiveNotification();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final notifType = notif['type']?.toString().toLowerCase() ?? 'system';
    final title = notif['title']?.toString() ?? 'Sanctuary Resonance';
    final notifData = notif['data'] as Map<String, dynamic>? ?? {};

    // 1. Direct 1:1 Message / Chat -> Direct jump into ChatDialogueScreen
    if (notifType.contains('message') || notifType.contains('chat')) {
      final matchId =
          notifData['match_id']?.toString() ?? notif['match_id']?.toString();
      final senderId = notifData['sender_id']?.toString() ??
          notif['sender_id']?.toString() ??
          'user_peer';
      final rawSenderName = notifData['sender_name']?.toString() ??
          title.replaceAll('Message from ', '').replaceAll(' 💬', '').trim();
      final senderName =
          rawSenderName.isNotEmpty ? rawSenderName : 'Sanctuary Seeker';

      final avatarUrl = notifData['sender_avatar']?.toString() ??
          notifData['avatar_url']?.toString() ??
          notifData['partner_photo']?.toString() ??
          '';
      final age = notifData['sender_age'] as int? ?? notifData['partner_age'] as int? ?? 24;

      ref.read(navigationIndexProvider.notifier).state = 2;

      if (matchId != null && matchId.isNotEmpty) {
        Navigator.of(context).pushNamed(
          ChatDialogueScreen.routeName,
          arguments: ChatDialogueArguments(
            matchId: matchId,
            recipientId: senderId,
            recipientName: senderName,
            recipientAge: age,
            recipientAvatarUrl: avatarUrl,
            isOnline: true,
            hasWaKey: true,
            sharedContextQuote: 'Deep Mindful Connection',
          ),
        );
      }
      return;
    }

    // 2. Sacred Match Ignited -> Direct jump to ChatDialogueScreen
    if (notifType.contains('match')) {
      final matchId =
          notifData['match_id']?.toString() ?? notif['match_id']?.toString();
      final partnerId = notifData['partner_id']?.toString() ??
          notif['partner_id']?.toString() ??
          'partner_user';
      final rawPartnerName = notifData['partner_name']?.toString() ??
          title
              .replaceAll('Sacred Match Ignited', '')
              .replaceAll('💫', '')
              .trim();
      final partnerName =
          rawPartnerName.isNotEmpty ? rawPartnerName : 'Soul Seeker';
      final avatarUrl = notifData['partner_photo']?.toString() ??
          notifData['sender_avatar']?.toString() ??
          notifData['avatar_url']?.toString() ??
          '';
      final age = notifData['partner_age'] as int? ?? notifData['sender_age'] as int? ?? 24;

      ref.read(navigationIndexProvider.notifier).state = 2;

      if (matchId != null && matchId.isNotEmpty) {
        Navigator.of(context).pushNamed(
          ChatDialogueScreen.routeName,
          arguments: ChatDialogueArguments(
            matchId: matchId,
            recipientId: partnerId,
            recipientName: partnerName,
            recipientAge: age,
            recipientAvatarUrl: avatarUrl,
            isOnline: true,
            hasWaKey: true,
            sharedContextQuote: 'Mutual Resonance Ignited',
          ),
        );
      }
      return;
    }

    // 3. New incoming direct letter -> If matchId, jump directly to ChatDialogueScreen
    if (notifType.contains('direct')) {
      final matchId = notifData['match_id']?.toString() ?? notif['match_id']?.toString();
      if (matchId != null && matchId.isNotEmpty) {
        final senderName = notifData['sender_name']?.toString() ??
            notifData['partner_name']?.toString() ??
            'Seeker';
        final senderId = notifData['sender_id']?.toString() ??
            notifData['partner_id']?.toString() ??
            'user_peer';
        final avatarUrl = notifData['sender_avatar']?.toString() ??
            notifData['partner_photo']?.toString() ??
            notifData['avatar_url']?.toString() ??
            '';
        final age = notifData['sender_age'] as int? ?? notifData['partner_age'] as int? ?? 24;

        ref.read(navigationIndexProvider.notifier).state = 2;
        Navigator.of(context).pushNamed(
          ChatDialogueScreen.routeName,
          arguments: ChatDialogueArguments(
            matchId: matchId,
            recipientId: senderId,
            recipientName: senderName,
            recipientAge: age,
            recipientAvatarUrl: avatarUrl,
            isOnline: true,
            hasWaKey: false,
            sharedContextQuote: 'Direct Resonance Letter Received',
          ),
        );
        return;
      }
      ref.read(navigationIndexProvider.notifier).state = 1;
      return;
    }

    if (notifType.contains('like') || notifType.contains('resonate')) {
      ref.read(navigationIndexProvider.notifier).state = 1;
      return;
    }

    // 4. Kinship referral reward / ad reward -> Jump to Growth PRO hub (tab 3)
    if (notifType.contains('referral') ||
        notifType.contains('reward') ||
        notifType.contains('growth') ||
        notifType.contains('ad')) {
      ref.read(navigationIndexProvider.notifier).state = 3;
      return;
    }

    // 5. KYC / Persona / Profile status notification -> Jump to Persona (tab 4)
    if (notifType.contains('kyc') ||
        notifType.contains('profile') ||
        notifType.contains('persona')) {
      ref.read(navigationIndexProvider.notifier).state = 4;
      return;
    }

    // 6. Custom route if specified
    final targetRoute = notifData['target_route']?.toString();
    if (targetRoute != null && targetRoute.isNotEmpty) {
      if (targetRoute == '/chats' || targetRoute == '/dialogues') {
        ref.read(navigationIndexProvider.notifier).state = 2;
      } else if (targetRoute == '/resonances') {
        ref.read(navigationIndexProvider.notifier).state = 1;
      } else if (targetRoute == '/growth') {
        ref.read(navigationIndexProvider.notifier).state = 3;
      } else if (targetRoute == '/persona' || targetRoute == '/profile') {
        ref.read(navigationIndexProvider.notifier).state = 4;
      } else {
        Navigator.of(context).pushNamed(targetRoute);
      }
      return;
    }

    // Fallback: switch to Resonances
    ref.read(navigationIndexProvider.notifier).state = 1;
  }

  void _dismissActiveNotification() {
    if (_activeNotificationOverlay != null) {
      try {
        _activeNotificationOverlay?.remove();
      } catch (_) {}
      _activeNotificationOverlay = null;
    }
  }

  void _showWhatsAppNotification(Map<String, dynamic> notif, bool isDark) {
    if (!mounted) return;

    // Immediately remove any active banner so there is strictly NO duplicate banner
    _dismissActiveNotification();

    final notifType = notif['type']?.toString().toLowerCase() ?? 'system';
    final rawTitle = notif['title']?.toString() ?? 'Sanctuary Resonance';
    final message =
        notif['message']?.toString() ?? notif['body']?.toString() ?? '';
    final notifId = notif['id']?.toString();
    final notifData = notif['data'] as Map<String, dynamic>? ?? {};

    // Format WhatsApp-style display title and sender initials
    String displayTitle = rawTitle;
    if (notifType.contains('message') || notifType.contains('chat')) {
      final rawSenderName = notifData['sender_name']?.toString() ??
          rawTitle.replaceAll('Message from ', '').replaceAll(' 💬', '').trim();
      displayTitle =
          rawSenderName.isNotEmpty ? rawSenderName : 'Sanctuary Seeker';
    }

    final avatarUrl = notifData['sender_avatar']?.toString() ??
        notifData['avatar_url']?.toString();

    // Mark as read on backend asynchronously
    if (notifId != null) {
      try {
        final apiClient = ref.read(apiClientProvider);
        apiClient.dio.post<dynamic>(
          '/api/v1/notifications/mark-read',
          data: {
            'notification_ids': [notifId],
            'notification_id': notifId
          },
        );
      } catch (_) {}
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _activeNotificationOverlay = OverlayEntry(
      builder: (context) => WhatsAppNotificationBanner(
        title: displayTitle,
        message: message,
        type: notifType,
        avatarUrl: avatarUrl,
        isDark: isDark,
        onTap: () {
          _dismissActiveNotification();
          _handleNotificationNavigation(notif);
        },
        onDismiss: () {
          _dismissActiveNotification();
        },
      ),
    );

    overlay.insert(_activeNotificationOverlay!);
  }

  @override
  void dispose() {
    _dismissActiveNotification();
    _notificationPoller?.cancel();
    _seenNotificationIds.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final navBg = isDark ? const Color(0xFF121815) : const Color(0xFFFAF8F5);

    final borderColor =
        isDark ? const Color(0xFF1E2B23) : const Color(0xFFE8E3DA);

    final activeColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final inactiveColor =
        isDark ? const Color(0xFF718096) : const Color(0xFF8C9B90);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final currentIdx = ref.read(navigationIndexProvider);
        if (currentIdx != 0) {
          // Switch back to Discovery feed tab if on another tab
          ref.read(navigationIndexProvider.notifier).state = 0;
          return;
        }

        // On Discovery tab: double back press to exit safely
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit Sanctuary'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? DarkSanctuaryTokens.background
            : LightSanctuaryTokens.background,
        body: IndexedStack(
          index: currentIndex,
          children: const [
            FeedScreen(),
            ResonancesScreen(),
            ChatsListScreen(),
            GrowthHubScreen(),
            MyPersonaScreen(),
          ],
        ),
        floatingActionButton: Container(
          margin: const EdgeInsets.only(bottom: 6),
          height: 44,
          child: FloatingActionButton.extended(
            heroTag: 'eva_sanctuary_fab',
            elevation: 6,
            backgroundColor: isDark ? const Color(0xFF1E2B23) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: activeColor.withOpacity(0.5),
                width: 1.2,
              ),
            ),
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    DarkSanctuaryTokens.primaryCoral,
                    Color(0xFF4E9F76),
                  ],
                ),
              ),
              child:
                  const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            label: Text(
              'Eva AI',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A2621),
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pushNamed(EvaSanctuaryScreen.routeName);
            },
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: navBg,
            border: Border(
              top: BorderSide(color: borderColor, width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.04),
                blurRadius: 16.0,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    currentIndex: currentIndex,
                    selectedIcon: Icons.explore_rounded,
                    unselectedIcon: Icons.explore_outlined,
                    label: 'Discovery',
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 1,
                    currentIndex: currentIndex,
                    selectedIcon: Icons.favorite_rounded,
                    unselectedIcon: Icons.favorite_outline_rounded,
                    label: 'Resonance',
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    isDark: isDark,
                    badgeCount: _unreadResonanceCount,
                  ),
                  _buildNavItem(
                    index: 2,
                    currentIndex: currentIndex,
                    selectedIcon: Icons.chat_bubble_rounded,
                    unselectedIcon: Icons.chat_bubble_outline_rounded,
                    label: 'Dialogues',
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    isDark: isDark,
                    badgeCount: _unreadChatCount,
                  ),
                  _buildNavItem(
                    index: 3,
                    currentIndex: currentIndex,
                    selectedIcon: Icons.spa_rounded,
                    unselectedIcon: Icons.spa_outlined,
                    label: 'Growth',
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 4,
                    currentIndex: currentIndex,
                    selectedIcon: Icons.person_rounded,
                    unselectedIcon: Icons.person_outline_rounded,
                    label: 'Persona',
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
    required Color activeColor,
    required Color inactiveColor,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            if (index == 1) setState(() => _unreadResonanceCount = 0);
            if (index == 2) setState(() => _unreadChatCount = 0);
            ref.read(navigationIndexProvider.notifier).state = index;
          },
          splashColor: activeColor.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withOpacity(isDark ? 0.16 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : unselectedIcon,
                      size: 22.0,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -4,
                        top: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEE8A70),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3.0),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

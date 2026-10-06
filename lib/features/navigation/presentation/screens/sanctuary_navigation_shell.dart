import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../chat/presentation/screens/chats_list_screen.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../profile/presentation/screens/my_persona_screen.dart';
import '../../../resonances/presentation/screens/resonances_screen.dart';
import '../../../rewards/presentation/screens/growth_hub_screen.dart';
import '../../../ai_sanctuary/presentation/screens/eva_sanctuary_screen.dart';
import '../../../../core/services/sanctuary_notification_service.dart';
import '../../../../core/storage/secure_session_storage.dart';
import '../../../resonances/presentation/controllers/resonances_controller.dart';
import '../../../profile/presentation/controllers/persona_controller.dart';
import '../../../chat/presentation/services/window_security_service.dart';
import '../widgets/ios_pwa_install_banner.dart';

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
    extends ConsumerState<SanctuaryNavigationShell>
    with WidgetsBindingObserver {
  DateTime? _lastBackPressTime;
  Timer? _notificationPoller;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  int _unreadResonanceCount = 0;
  int _unreadChatCount = 0;
  final Set<String> _seenNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(navigationIndexProvider.notifier).state = widget.initialIndex;
        }
      });
    }
    WindowSecurityService.applyPolicyForTab(widget.initialIndex);
    _initializeSeenAndStartPoller();
    _listenToRealtimeWebSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SanctuaryNotificationService.syncStoredFcmToken();
    }
  }

  Future<void> _initializeSeenAndStartPoller() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ur_heart_profile_setup_completed', true);
      await prefs.setBool('ur_heart_has_entered_sanctuary', true);
      final storedSeen = prefs.getStringList('sanctuary_seen_notification_ids') ?? [];
      _seenNotificationIds.addAll(storedSeen);

      final secureToken = await SecureSessionStorage.instance.getAuthToken();
      final authToken = (secureToken != null && secureToken.isNotEmpty)
          ? secureToken
          : (prefs.getString('ur_heart_auth_token') ?? prefs.getString('auth_token'));
      if (authToken != null && authToken.isNotEmpty) {
        SanctuaryNotificationService.syncStoredFcmToken(authToken);
      }
    } catch (_) {}

    if (mounted) {
      if (widget.initialIndex != 0) {
        ref.read(navigationIndexProvider.notifier).state = widget.initialIndex;
      }
      _startNotificationPoller();
    }
  }

  void _listenToRealtimeWebSocket() {
    try {
      final wsService = ref.read(chatWebSocketServiceProvider);
      _wsSubscription = wsService.eventStream.listen((event) {
        if (!mounted) return;
        final type = event['type']?.toString();
        final action = event['action']?.toString();

        if (type == 'sanctuary_notification') {
          final notif = event['notification'];
          if (notif is Map<String, dynamic>) {
            final nType = notif['type']?.toString().toLowerCase() ?? '';
            if (nType.contains('like') ||
                nType.contains('resonate') ||
                nType.contains('match') ||
                nType.contains('direct')) {
              ref.read(resonancesControllerProvider.notifier).loadResonances();
            }
            _dispatchSingleNotification(notif);
          }
        } else if (action == 'new_message' || type == 'dialogue_message') {
          final senderName = event['sender_name']?.toString() ?? 'Sanctuary Seeker';
          final content = event['content']?.toString() ?? event['text']?.toString() ?? 'New message';
          final matchId = event['match_id']?.toString() ?? '';
          final senderId = event['sender_id']?.toString() ?? '';
          final notifMap = {
            'id': 'ws_${DateTime.now().millisecondsSinceEpoch}',
            'type': 'message',
            'title': 'Message from $senderName 💬',
            'body': content,
            'match_id': matchId,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
            'data': {
              'match_id': matchId,
              'sender_id': senderId,
              'sender_name': senderName,
              'message': content,
            }
          };
          _dispatchSingleNotification(notifMap);
        }
      });
    } catch (_) {}
  }

  void _startNotificationPoller() {
    _pollNotifications();
    _notificationPoller = Timer.periodic(const Duration(seconds: 15), (_) {
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
          int chatCount = 0;
          int resonanceCount = 0;
          for (final notif in unreadList) {
            final notifId = notif['id']?.toString();
            if (notifId != null) {
              _seenNotificationIds.add(notifId);
            }
            final nType = notif['type']?.toString().toLowerCase() ?? '';
            if (nType.contains('message') || nType.contains('chat')) {
              chatCount++;
            } else {
              resonanceCount++;
            }
          }
          if (mounted) {
            setState(() {
              _unreadChatCount += chatCount;
              _unreadResonanceCount += resonanceCount;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _dispatchSingleNotification(Map<String, dynamic> notif) async {
    final notifId = notif['id']?.toString() ?? notif['data']?['notif_id']?.toString();
    if (notifId != null && SanctuaryNotificationService.instance.markNotificationSeen(notifId)) {
      return;
    }
    if (notifId != null && _seenNotificationIds.contains(notifId)) {
      return;
    }
    if (notifId != null) {
      _seenNotificationIds.add(notifId);
      if (!notifId.startsWith('ws_')) {
        ref.read(apiClientProvider).dio.post<dynamic>(
          '/api/v1/notifications/mark-read',
          data: {'notification_id': notifId},
        ).ignore();
      }
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
      } else if (nType == 'streak_claimed' ||
          nType.contains('claimed') ||
          nType.contains('secured')) {
        final streakVal = nData['streak_count'] as int? ?? 1;
        final boostVal = nData['boost_points'] as int?;
        SanctuaryNotificationService.instance.showStreakSecuredNotification(
          streakCount: streakVal,
          title: nTitle.isNotEmpty ? nTitle : '🔥 Day $streakVal Streak Secured!',
          body: nBody.isNotEmpty
              ? nBody
              : 'You earned +1 Boost Point! Your profile is prioritized at the top of the discovery deck for 24 hours.',
          boostPoints: boostVal,
        );
      } else if (nType == 'streak_broken' || nType.contains('broken')) {
        SanctuaryNotificationService.instance.showSystemNotification(
          id: (notifId ?? 'notif').hashCode,
          title: nTitle.isNotEmpty ? nTitle : '🥀 Streak Broken & Downgraded',
          body: nBody.isNotEmpty
              ? nBody
              : 'Your sanctuary streak expired. Take a reflection to resurrect your presence.',
          subText: 'Sanctuary Growth',
        );
      } else if (nType.contains('streak') || nType.contains('expir')) {
        final streakVal = nData['streak_count'] as int? ?? 1;
        final hoursVal =
            nData['hours_left'] as int? ?? nData['hours_remaining'] as int? ?? 4;
        SanctuaryNotificationService.instance.showStreakAlertNotification(
          streakCount: streakVal,
          hoursRemaining: hoursVal,
          title: nTitle.isNotEmpty ? nTitle : null,
          body: nBody.isNotEmpty ? nBody : null,
        );
      } else if (nType.contains('pass')) {
        final aName = nData['sender_name']?.toString() ??
            nData['actor_name']?.toString() ??
            'A seeker';
        SanctuaryNotificationService.instance.showSystemNotification(
          id: (notifId ?? 'notif').hashCode,
          title: 'Profile Passed 🍃',
          body: '$aName passed your resonance card.',
        );
      } else if (nType == 'like' || nType.contains('resonate')) {
        final aName = nData['sender_name']?.toString() ??
            nData['actor_name']?.toString() ??
            'A seeker';
        final aId = nData['sender_id']?.toString() ??
            nData['actor_id']?.toString() ??
            'seeker_1';
        final aAvatar = nData['sender_avatar']?.toString() ??
            nData['avatar_url']?.toString();
        SanctuaryNotificationService.instance.showResonanceNotification(
          senderName: aName,
          actorId: aId,
          avatarUrl: aAvatar,
        );
      } else if (nType.contains('kyc')) {
        SanctuaryNotificationService.instance.showSystemNotification(
          id: (notifId ?? 'kyc_notif').hashCode,
          title: nTitle,
          body: nBody,
          subText: 'Sanctuary Shield',
          payload: jsonEncode({'target_route': '/settings'}),
        );
      } else if (nType.contains('ad') || nType.contains('reward')) {
        SanctuaryNotificationService.instance.showSystemNotification(
          id: (notifId ?? 'ad_notif').hashCode,
          title: nTitle,
          body: nBody,
          subText: 'Sanctuary Rewards',
          payload: jsonEncode({'target_route': '/main'}),
        );
      } else {
        SanctuaryNotificationService.instance.showSystemNotification(
          id: (notifId ?? 'notif').hashCode,
          title: nTitle,
          body: nBody,
        );
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'sanctuary_seen_notification_ids', _seenNotificationIds.toList());
    } catch (_) {}

    if (mounted) {
      setState(() {
        if (nType.contains('message') || nType.contains('chat')) {
          _unreadChatCount++;
        } else {
          _unreadResonanceCount++;
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationPoller?.cancel();
    _wsSubscription?.cancel();
    _seenNotificationIds.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(navigationIndexProvider, (prev, next) {
      WindowSecurityService.applyPolicyForTab(next);
    });

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
        body: Column(
          children: [
            IosPwaInstallBanner(isDark: isDark),
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: const [
                  FeedScreen(),
                  ResonancesScreen(),
                  ChatsListScreen(),
                  GrowthHubScreen(),
                  MyPersonaScreen(),
                ],
              ),
            ),
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
            if (index == 1) {
              setState(() => _unreadResonanceCount = 0);
              ref.read(resonancesControllerProvider.notifier).loadResonances();
            }
            if (index == 2) setState(() => _unreadChatCount = 0);
            if (index == 4) {
              ref.read(personaControllerProvider.notifier).refreshProfile();
            }
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../chat/presentation/screens/chats_list_screen.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../profile/presentation/screens/my_persona_screen.dart';
import '../../../resonances/presentation/screens/resonances_screen.dart';
import '../../../rewards/presentation/screens/growth_hub_screen.dart';

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

  @override
  void initState() {
    super.initState();
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
      final response = await apiClient.dio.get<Map<String, dynamic>>('/api/v1/notifications');
      if (response.statusCode == 200 && response.data != null) {
        final notifications = response.data!['notifications'] as List<dynamic>? ?? [];
        final unreadList = notifications
            .cast<Map<String, dynamic>>()
            .where((n) => n['is_read'] != true && !_seenNotificationIds.contains(n['id']?.toString()))
            .toList();

        if (unreadList.isNotEmpty && mounted) {
          final isDark = ref.read(themeProvider).activeTheme == SanctuaryTheme.dark;
          for (final notif in unreadList) {
            final notifId = notif['id']?.toString();
            if (notifId != null) _seenNotificationIds.add(notifId);
            _showNotificationBanner(notif, isDark);
          }

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

  void _showNotificationBanner(Map<String, dynamic> notif, bool isDark) {
    final notifType = notif['type']?.toString().toLowerCase() ?? 'system';
    final title = notif['title']?.toString() ?? 'Sanctuary Resonance';
    final message = notif['message']?.toString() ?? '';
    final notifId = notif['id']?.toString();

    IconData icon = Icons.notifications_active;
    Color iconColor = const Color(0xFFE58B68);
    int targetTab = 1;

    if (notifType.contains('like') || notifType.contains('resonate')) {
      icon = Icons.favorite_rounded;
      iconColor = const Color(0xFFE58B68);
      targetTab = 1;
    } else if (notifType.contains('message') || notifType.contains('chat')) {
      icon = Icons.chat_bubble_rounded;
      iconColor = const Color(0xFF4E9F76);
      targetTab = 2;
    } else if (notifType.contains('match')) {
      icon = Icons.auto_awesome;
      iconColor = const Color(0xFFD4AF37);
      targetTab = 1;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isDark ? const Color(0xFF1E2B23) : const Color(0xFFFFFFFF),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: iconColor.withOpacity(0.5), width: 1.2),
        ),
        elevation: 6,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.15),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF1A2621),
                    ),
                  ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF718096),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: iconColor,
          onPressed: () {
            ref.read(navigationIndexProvider.notifier).state = targetTab;
          },
        ),
      ),
    );

    // Mark as read on backend
    if (notifId != null) {
      try {
        final apiClient = ref.read(apiClientProvider);
        apiClient.dio.post<dynamic>('/api/v1/notifications/mark-read', data: {'notification_ids': [notifId]});
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _notificationPoller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final navBg = isDark
        ? const Color(0xFF121815)
        : const Color(0xFFFAF8F5);

    final borderColor = isDark
        ? const Color(0xFF1E2B23)
        : const Color(0xFFE8E3DA);

    final activeColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final inactiveColor = isDark
        ? const Color(0xFF718096)
        : const Color(0xFF8C9B90);

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
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
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

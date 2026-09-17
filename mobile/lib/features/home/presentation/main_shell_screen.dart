import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/features/chat/presentation/chat_room_screen.dart';
import 'package:ur_heart/features/feed/presentation/feed_screen.dart';
import 'package:ur_heart/features/matches/presentation/matches_screen.dart';
import 'package:ur_heart/features/profile/presentation/profile_vault_screen.dart';

/// Master Navigation Shell providing access to:
/// 1. Discovery Feed (Swiping, Like, Pass/Ignore, Direct DM)
/// 2. Matches & Connections
/// 3. Direct Encrypted Chat Room
/// 4. Profile & Streak Vault
class MainShellScreen extends StatefulWidget {
  final String lang;
  final int initialIndex;

  const MainShellScreen({
    super.key,
    this.lang = 'en',
    this.initialIndex = 0,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      FeedScreen(
        lang: widget.lang,
        onLikeTap: () => _onTabSelected(1),
        onDirectDmTap: () => _onTabSelected(2),
      ),
      MatchesScreen(
        lang: widget.lang,
        onExploreTap: () => _onTabSelected(0),
      ),
      ChatRoomScreen(
        lang: widget.lang,
      ),
      ProfileVaultScreen(
        lang: widget.lang,
      ),
    ];

    return Scaffold(
      backgroundColor: URHeartColors.canvasBackground,
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: URHeartColors.cardSurface,
          border: const Border(
            top: BorderSide(color: URHeartColors.surfaceRaised, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  label: 'Discover',
                  icon: Icons.local_fire_department_rounded,
                  activeColor: URHeartColors.brandPrimary,
                ),
                _buildNavItem(
                  index: 1,
                  label: 'Matches',
                  icon: Icons.favorite_rounded,
                  activeColor: URHeartColors.brandPrimary,
                ),
                _buildNavItem(
                  index: 2,
                  label: 'Chat',
                  icon: Icons.chat_bubble_rounded,
                  activeColor: URHeartColors.brandSecondary,
                ),
                _buildNavItem(
                  index: 3,
                  label: 'Profile',
                  icon: Icons.person_rounded,
                  activeColor: URHeartColors.accentGold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required Color activeColor,
    String? badgeText,
  }) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? activeColor : URHeartColors.textMuted,
                ),
                if (badgeText != null && !isSelected)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: URHeartColors.brandPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : URHeartColors.textMuted,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

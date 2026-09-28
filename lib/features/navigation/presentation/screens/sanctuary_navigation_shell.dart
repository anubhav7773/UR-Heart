import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex != 0) {
        ref.read(navigationIndexProvider.notifier).state = widget.initialIndex;
      }
    });
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
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
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
                child: Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  size: 22.0,
                  color: isSelected ? activeColor : inactiveColor,
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

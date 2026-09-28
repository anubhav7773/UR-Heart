import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/age_gate_auth_screen.dart';
import '../../features/auth/presentation/screens/consent_screen.dart';
import '../../features/auth/presentation/screens/magic_link_screen.dart';
import '../../features/profile_setup/presentation/screens/profile_setup_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/feed/presentation/screens/ignored_profiles_screen.dart';
import '../../features/resonances/presentation/screens/resonances_screen.dart';
import '../../features/chat/presentation/screens/chats_list_screen.dart';
import '../../features/chat/presentation/screens/chat_dialogue_screen.dart';
import '../../features/profile/presentation/screens/my_persona_screen.dart';
import '../../features/legal_vault/presentation/screens/vault_legal_screen.dart';
import '../../features/settings/presentation/screens/sanctuary_settings_screen.dart';
import '../../features/settings/presentation/screens/superadmin_kyc_desk_screen.dart';
import '../../features/rewards/presentation/screens/growth_hub_screen.dart';
import '../../features/navigation/presentation/screens/sanctuary_navigation_shell.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../theme/theme_controller.dart';

/// Root Application Widget wrapped in Riverpod Consumer
/// Dynamically updates between Light Sanctuary and Dark Sanctuary ThemeData
class URHeartApp extends ConsumerWidget {
  const URHeartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;

    return MaterialApp(
      title: 'UR-Heart',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      initialRoute: ConsentScreen.routeName,
      routes: {
        ConsentScreen.routeName: (context) => const ConsentScreen(),
        AgeGateAuthScreen.routeName: (context) => const AgeGateAuthScreen(),
        MagicLinkScreen.routeName: (context) => const MagicLinkScreen(),
        ProfileSetupScreen.routeName: (context) => const ProfileSetupScreen(),
        SanctuaryNavigationShell.routeName: (context) => const SanctuaryNavigationShell(),
        FeedScreen.routeName: (context) => const SanctuaryNavigationShell(initialIndex: 0),
        ResonancesScreen.routeName: (context) => const SanctuaryNavigationShell(initialIndex: 1),
        ChatsListScreen.routeName: (context) => const SanctuaryNavigationShell(initialIndex: 2),
        GrowthHubScreen.routeName: (context) => const SanctuaryNavigationShell(initialIndex: 3),
        MyPersonaScreen.routeName: (context) => const SanctuaryNavigationShell(initialIndex: 4),
        IgnoredProfilesScreen.routeName: (context) => const IgnoredProfilesScreen(),
        ChatDialogueScreen.routeName: (context) => const ChatDialogueScreen(),
        VaultLegalScreen.routeName: (context) => const VaultLegalScreen(),
        SanctuarySettingsScreen.routeName: (context) => const SanctuarySettingsScreen(),
        SuperadminKycDeskScreen.routeName: (context) => const SuperadminKycDeskScreen(),
      },
    );
  }

  static ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: LightSanctuaryTokens.background,
      cardColor: LightSanctuaryTokens.surfaceCard,
      colorScheme: const ColorScheme.light(
        surface: LightSanctuaryTokens.surfaceCard,
        primary: LightSanctuaryTokens.primaryPine,
        secondary: LightSanctuaryTokens.terracottaAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LightSanctuaryTokens.background,
        elevation: 0,
        iconTheme: IconThemeData(color: LightSanctuaryTokens.textHeadline),
      ),
      textTheme: const TextTheme(
        headlineLarge: AppTypography.titleH1,
        headlineMedium: AppTypography.titleH2,
        bodyLarge: AppTypography.bodyStandard,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DarkSanctuaryTokens.background,
      cardColor: DarkSanctuaryTokens.surfaceCard,
      colorScheme: const ColorScheme.dark(
        surface: DarkSanctuaryTokens.surfaceCard,
        primary: DarkSanctuaryTokens.primaryCoral,
        secondary: DarkSanctuaryTokens.secondaryPine,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DarkSanctuaryTokens.background,
        elevation: 0,
        iconTheme: IconThemeData(color: DarkSanctuaryTokens.textHeadline),
      ),
      textTheme: const TextTheme(
        headlineLarge: AppTypography.titleH1,
        headlineMedium: AppTypography.titleH2,
        bodyLarge: AppTypography.bodyStandard,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
      ),
    );
  }
}

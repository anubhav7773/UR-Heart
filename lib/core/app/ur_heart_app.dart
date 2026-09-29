import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/secure_session_storage.dart';
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
import '../../features/ai_sanctuary/presentation/screens/eva_sanctuary_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../theme/theme_controller.dart';

/// Root Application Widget wrapped in Riverpod Consumer
/// Dynamically updates between Light Sanctuary and Dark Sanctuary ThemeData
class URHeartApp extends ConsumerWidget {
  final String? initialRoute;

  const URHeartApp({super.key, this.initialRoute});

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
      initialRoute: initialRoute,
      home: initialRoute == null ? const SanctuaryAppGateway() : null,
      routes: {
        ConsentScreen.routeName: (context) => const ConsentScreen(),
        AgeGateAuthScreen.routeName: (context) => const AgeGateAuthScreen(),
        MagicLinkScreen.routeName: (context) => const MagicLinkScreen(),
        '/magic-link': (context) => const MagicLinkScreen(),
        ProfileSetupScreen.routeName: (context) => const ProfileSetupScreen(),
        SanctuaryNavigationShell.routeName: (context) => const SanctuaryNavigationShell(),
        '/sanctuary': (context) => const SanctuaryNavigationShell(),
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
        EvaSanctuaryScreen.routeName: (context) => const EvaSanctuaryScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/verify-email' || settings.name == '/magic-link') {
          String? email;
          if (settings.arguments is Map) {
            email = (settings.arguments as Map)['email']?.toString();
          } else if (settings.arguments is String) {
            email = settings.arguments as String;
          }
          return MaterialPageRoute(
            builder: (context) => MagicLinkScreen(email: email),
            settings: settings,
          );
        }
        return null;
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

/// Lightweight intelligent startup gateway widget
/// Evaluates session persistence instantly without screen flicker
class SanctuaryAppGateway extends StatefulWidget {
  const SanctuaryAppGateway({super.key});

  @override
  State<SanctuaryAppGateway> createState() => _SanctuaryAppGatewayState();
}

class _SanctuaryAppGatewayState extends State<SanctuaryAppGateway> {
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _determineStartupTarget();
  }

  Future<void> _determineStartupTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isProfileSetupDone = (prefs.getBool('ur_heart_profile_setup_completed') ?? false) ||
                                 (prefs.getBool('ur_heart_has_entered_sanctuary') ?? false) ||
                                 (prefs.getString('profile_full_name')?.isNotEmpty ?? false) ||
                                 (prefs.getString('profile_bio')?.isNotEmpty ?? false) ||
                                 (prefs.getString('profile_photo_slot_1')?.isNotEmpty ?? false);
      final secureToken = await SecureSessionStorage.instance.getAuthToken();
      final secureEmail = await SecureSessionStorage.instance.getUserEmail();
      final hasAuth = (secureToken != null && secureToken.isNotEmpty) ||
                      (secureEmail != null && secureEmail.isNotEmpty) ||
                      (prefs.getString('ur_heart_auth_token')?.isNotEmpty ?? false) ||
                      (prefs.getString('auth_token')?.isNotEmpty ?? false) ||
                      (prefs.getString('ur_heart_user_email')?.isNotEmpty ?? false);
      final isConsentGiven = (prefs.getBool('urheart_theme_permanently_locked') ?? false) ||
                             (prefs.getBool('ur_heart_theme_locked') ?? false) ||
                             (prefs.getBool('ur_heart_consent_given') ?? false);

      if (!mounted) return;
      setState(() {
        if (hasAuth && isProfileSetupDone) {
          _targetScreen = const SanctuaryNavigationShell();
        } else if (hasAuth && !isProfileSetupDone) {
          _targetScreen = const ProfileSetupScreen();
        } else if (isConsentGiven) {
          _targetScreen = const AgeGateAuthScreen();
        } else {
          _targetScreen = const ConsentScreen();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _targetScreen = const ConsentScreen();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetScreen != null) {
      return _targetScreen!;
    }

    return const Scaffold(
      backgroundColor: Color(0xFF0F1512),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, color: Color(0xFF4E9F76), size: 48),
            SizedBox(height: 16),
            Text(
              'UR-Heart',
              style: TextStyle(
                fontFamily: 'Serif',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF3F5F4),
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

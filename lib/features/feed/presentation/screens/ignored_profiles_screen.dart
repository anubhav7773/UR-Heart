import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../widgets/ignored_profile_tile.dart';
import '../controllers/ignored_profiles_controller.dart';

class IgnoredProfilesScreen extends ConsumerWidget {
  const IgnoredProfilesScreen({super.key});

  static const String routeName = '/ignored';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final vaultState = ref.watch(ignoredProfilesControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final bg = isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background;
    final primaryText = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subText = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: primaryText),
        title: Text(
          'Ignored Profiles',
          style: TextStyle(
            fontFamily: 'Serif',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryText,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: vaultState.passedProfiles.isEmpty
            ? Center(
                child: Text(
                  'Your pass vault is currently quiet and empty.',
                  style: TextStyle(color: subText, fontSize: 14),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: vaultState.passedProfiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final candidate = vaultState.passedProfiles[index];
                        final String id = candidate is Map
                            ? (candidate['id'] as String? ?? '')
                            : (candidate.id as String? ?? '');
                        final String name = candidate is Map
                            ? (candidate['full_name'] as String? ?? 'Sanctuary Member')
                            : (candidate.fullName as String? ?? 'Sanctuary Member');

                        return IgnoredProfileTile(
                          candidate: candidate,
                          isDark: isDark,
                          onRevisitTap: () async {
                            await ref
                                .read(ignoredProfilesControllerProvider.notifier)
                                .revisitProfile(id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$name restored to discovery deck.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      'Passed profiles are preserved in your encrypted local enclave under DPDP Act 2023. Revisit at any time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: subText.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

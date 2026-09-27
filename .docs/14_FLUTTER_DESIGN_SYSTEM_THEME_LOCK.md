# 14_FLUTTER_DESIGN_SYSTEM_THEME_LOCK.md: STITCH DESIGN SYSTEM & PERMANENT THEME LOCKER
# Project: UR-Heart (Mindful Dating Sanctuary)
# Visual Fidelity: 100% Strict Match with Imported Stitch UI
# Core Policy: Install in Light Mode by Default -> Single One-Time Mode Selection with Permanent Lock

---

## 1. THEME LOCK ARCHITECTURE & INSTALL-TIME GOVERNANCE

UR-Heart visual sanctuary consistency ko prioritize karta hai. Standard apps mein user settings mein jakar bar-bar theme toggle karte hain, jisse dynamic rendering overhead aur caching issues aate hain. UR-Heart ek deliberate, permanent decision model follow karta hai:

                            [App Fresh Installation]
                                        │
                                        ▼
                       ┌─────────────────────────────────┐
                       │ DEFAULT STATE: LIGHT SANCTUARY  │
                       │ - Applied immediately on boot   │
                       │ - ur_heart_theme_mode = 'light' │
                       │ - ur_heart_theme_locked = false │
                       └────────────────┬────────────────┘
                                        │
                                        ▼
                       ┌─────────────────────────────────┐
                       │ SCREEN 1: MINDFUL CONSENT       │
                       │ Header Pill: [ ☀️ Light Mode ▾ ]│ (Replaces 'English')
                       └────────────────┬────────────────┘
                                        │
             User taps Header Pill to switch to Dark Sanctuary[cite: 2, 28]?
                                        │
                       ┌────────────────┴────────────────┐
                       ▼ YES                             ▼ NO (Taps "I Agree & Continue")
         ┌───────────────────────────┐         ┌───────────────────────────┐
         │ PERMANENT LOCK DISCLAIMER │         │ AUTO-LOCK CURRENT THEME   │
         │ Modal Dialog Appears:     │         │ - Locks Light Mode        │
         │ "Once chosen, display mode│         │ - ur_heart_theme_locked = │
         │ cannot be changed ever."  │         │   true                    │
         └─────────────┬─────────────┘         └───────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         ▼ Confirms                  ▼ Cancels
┌─────────────────────────┐   ┌─────────────────────────┐
│ LOCK DARK SANCTUARY     │   │ REMAINS IN LIGHT MODE   │
│ - Theme = Dark Mode     │   │ Header remains editable │
│ - ur_heart_theme_locked │   │ until onboarding submit │
│   = true                │   └─────────────────────────┘
│ - Header switch locked  │
└─────────────────────────┘   
PNG


### 1.1 Core Rules for Antigravity
1. **Fresh Install Default**: App fresh install hone par hamesha **Light Mode** palette mein load hogi[cite: 15, 28].
2. **Top Header Pill Transformation (Screen 1)**: Imported UI ke top center par jahan `English ▾` dropdown tha, wahan ab `ThemeSelectorPill` render hoga[cite: 28].
3. **One-Time Selection Opportunity**: User ko theme switch karne ka mauka sirf onboarding ke doran Screen 1 par milta hai[cite: 2, 28].
4. **Mandatory Disclaimer Modal**: Jab user pill par tap karke mode switch karne ki koshish kare, to system ek explicit disclaimer modal trigger karega:
   * *"Attention: This choice is permanent. Once confirmed, you cannot change the visual mode of UR-Heart. The entire app will forever remain in this mode on this device."*
5. **Irrevocable Storage Lock**: Ek baar confirm hone par ya Screen 1 ke "I Agree & Continue" tap hone par, state `FlutterSecureStorage` aur `SharedPreferences` mein `is_theme_locked = true` ke sath lock ho jayegi[cite: 28]. Iske baad app ke kisi bhi screen (settings included) par theme switcher render nahi hoga[cite: 14, 27].

---

## 2. STITCH IMPORTED DESIGN TOKENS (100% PRECISION MATRIX)

Imported screens (`screenshot.png` through `screenshot33.png`) ke basis par color palettes, typography, aur elevations freeze kiye gaye hain[cite: 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27]:

### 2.1 Dark Sanctuary Palette (Screens 1 to 13 - Dark)[cite: 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

```dart
class DarkSanctuaryTokens {
  // Backgrounds & Surface
  static const Color background = Color(0xFF0F1914);       // Deep sanctuary obsidian green[cite: 2]
  static const Color surfaceCard = Color(0xFF1B2923);      // Elevated card container surface[cite: 2, 11]
  static const Color surfaceCardBorder = Color(0xFF263830);// Subtle container border[cite: 2]
  static const Color bottomNavBackground = Color(0xFF0D1612);// Bottom dock container[cite: 6]
  
  // Accents & Buttons
  static const Color primaryCoral = Color(0xFFE27D60);     // Terracotta coral main action
  static const Color primaryCoralGlow = Color(0x33E27D60); // Button shadow/glow[cite: 4]
  static const Color secondaryPine = Color(0xFF1E382B);    // Deep pine pill/button surface[cite: 6]
  static const Color accentGold = Color(0xFFE9C46A);       // Sparkle / energy accents[cite: 9]
  static const Color verifiedBadge = Color(0xFF2EC4B6);    // Verified teal badge[cite: 3, 5, 12]

  // Typography Colors
  static const Color textHeadline = Color(0xFFFFFFFF);     // Pure white editorial titles[cite: 2]
  static const Color textHeadlineItalic = Color(0xFFE27D60);// Terracotta italic accent words[cite: 2, 3]
  static const Color textBody = Color(0xFFD8E2DC);         // Soft cream reading body[cite: 2]
  static const Color textMuted = Color(0xFF8A9A90);        // Subtitle & label grey-green[cite: 2, 3]
  static const Color textLegalNotice = Color(0xFF6B7C72);   // Footer statutory notices[cite: 2]

  // Inputs & Controls
  static const Color inputBackground = Color(0xFF131F19);   // Form field container[cite: 3]
  static const Color inputBorder = Color(0xFF22362C);       // Field border stroke[cite: 3]
  static const Color checkboxActive = Color(0xFFE27D60);    // Checked box fill[cite: 2]
}
2.2 Light Sanctuary Palette (Screens 21 to 33 - Light)
Dart


class LightSanctuaryTokens {
  // Backgrounds & Surface
  static const Color background = Color(0xFFF9F7F2);       // Warm cream / soft parchment[cite: 15, 28]
  static const Color surfaceCard = Color(0xFFFFFFFF);      // Crisp pure white elevated sheet[cite: 15, 28]
  static const Color surfaceCardBorder = Color(0xFFEBE6DC);// Soft warm card border[cite: 15, 28]
  static const Color bottomNavBackground = Color(0xFFFFFFFF);// Clean white bottom bar[cite: 19]

  // Accents & Buttons
  static const Color primaryPine = Color(0xFF17382B);      // Deep forest pine action button[cite: 15, 28]
  static const Color primaryPineGlow = Color(0x2217382B);  // Subtle button drop shadow[cite: 15, 28]
  static const Color terracottaAccent = Color(0xFFD96B4F); // Editorial terracotta italic title[cite: 15, 28]
  static const Color chipBackground = Color(0xFFF2EFE9);   // Tag & selection pills[cite: 19]
  static const Color verifiedBadge = Color(0xFF2B8A6E);    // Verified green badge[cite: 16, 18, 25]

  // Typography Colors
  static const Color textHeadline = Color(0xFF15221C);     // Deep charcoal editorial headline[cite: 15, 28]
  static const Color textHeadlineItalic = Color(0xFFD96B4F);// Terracotta italic accent phrase[cite: 15, 28]
  static const Color textBody = Color(0xFF4A5851);         // Slate readable body copy[cite: 15, 28]
  static const Color textMuted = Color(0xFF7A8981);        // Legal disclaimers & subtitles[cite: 15, 28]
  static const Color textLegalNotice = Color(0xFF8F9C95);   // Statutory micro footer[cite: 15, 28]

  // Inputs & Controls
  static const Color inputBackground = Color(0xFFF7F5F0);   // Neutral light input box[cite: 16]
  static const Color inputBorder = Color(0xFFE4DFD5);       // Subtle input contour[cite: 16]
  static const Color checkboxActive = Color(0xFF17382B);    // Forest pine checked square[cite: 15, 28]
}
3. TYPOGRAPHY SYSTEM (EDITORIAL SERIF + INTENTIONAL SANS)
Stitch UI modern intentional aesthetic create karne ke liye do primary font families use karta hai:   
PNG
+ 2

Editorial Serif (Playfair Display or Cormorant Garamond): Screen titles, philosophical quotes, aur poetic italic highlights ke liye (Mindful consent. Real trust.).   
PNG
+ 2

Clean Sans-Serif (Plus Jakarta Sans or Inter): Form fields, buttons, body copy, statutory notices aur chat bubbles ke liye.   
PNG
+ 2

Dart


class SanctuaryTypography {
  // Title H1 (e.g., "Mindful consent.", "Real people.")[cite: 2, 3, 15, 16]
  static const TextStyle titleH1 = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 32.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.15,
  );

  // Poetic Italic Sub-title (e.g., "Real trust.", "Real resonance.")[cite: 2, 3, 15, 16]
  static const TextStyle titleH1Italic = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 32.0,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.3,
    height: 1.15,
  );

  // Body Standard (e.g. Consent descriptions)[cite: 2, 15, 28]
  static const TextStyle bodyStandard = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  // Legal / Accordion Header[cite: 2, 15, 28]
  static const TextStyle accordionCategory = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  // Primary Button Text[cite: 2, 15, 28]
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
}
4. RIVERPOD PERMANENT THEME LOCK CONTROLLER
Theme state management pure app mein Riverpod state notifier ke through bind hai:

Dart


// lib/core/theme/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SanctuaryTheme { light, dark }

class ThemeState {
  final SanctuaryTheme activeTheme;
  final bool isLocked;

  const ThemeState({
    required this.activeTheme,
    required this.isLocked,
  });

  ThemeState copyWith({SanctuaryTheme? activeTheme, bool? isLocked}) {
    return ThemeState(
      activeTheme: activeTheme ?? this.activeTheme,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class ThemeController extends StateNotifier<ThemeState> {
  static const String _themeKey = 'ur_heart_theme_mode';
  static const String _lockKey = 'ur_heart_theme_locked';

  ThemeController()
      : super(const ThemeState(activeTheme: SanctuaryTheme.light, isLocked: false)) {
    _loadThemeFromPersistence();
  }

  Future<void> _loadThemeFromPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool(_lockKey) ?? false;
    final savedThemeString = prefs.getString(_themeKey);

    // DEFAULT ON FRESH INSTALL: Light Sanctuary[cite: 15, 28]
    SanctuaryTheme theme = SanctuaryTheme.light;
    if (savedThemeString == 'dark') {
      theme = SanctuaryTheme.dark;
    }

    state = ThemeState(activeTheme: theme, isLocked: isLocked);
  }

  /// Called ONLY on Screen 1 when user confirms switch in the disclaimer modal[cite: 28]
  Future<void> switchAndLockTheme(SanctuaryTheme newTheme) async {
    if (state.isLocked) return; // Prevent any modifications once locked

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, newTheme == SanctuaryTheme.dark ? 'dark' : 'light');
    await prefs.setBool(_lockKey, true); // PERMANENTLY LOCKED

    state = ThemeState(activeTheme: newTheme, isLocked: true);
  }

  /// Lock current default light mode permanently when user agrees to consent[cite: 28]
  Future<void> lockCurrentThemePermanently() async {
    if (state.isLocked) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, state.activeTheme == SanctuaryTheme.dark ? 'dark' : 'light');
    await prefs.setBool(_lockKey, true);

    state = state.copyWith(isLocked: true);
  }
}

final themeProvider = StateNotifierProvider<ThemeController, ThemeState>((ref) {
  return ThemeController();
});
5. TOP HEADER PILL REPLACEMENT (ThemeSelectorPill)
Screen 1 ke top header mein English ▾ ko replace karke ye component embed kiya jata hai[cite: 28]:

Dart


// lib/core/theme/widgets/theme_selector_pill.dart[cite: 28]
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme_controller.dart';
import 'permanent_theme_lock_dialog.dart';

class ThemeSelectorPill extends ConsumerWidget {
  const ThemeSelectorPill({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;

    // If theme is already locked permanently, render locked static badge
    if (themeState.isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E382B) : const Color(0xFFF2EFE9),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 14.0, color: isDark ? Colors.white : Colors.black87),
            const SizedBox(width: 6.0),
            Text(
              isDark ? "Dark Sanctuary" : "Light Sanctuary",
              style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
      );
    }

    // Editable Header Pill (Available ONLY before consent submission)[cite: 28]
    return InkWell(
      borderRadius: BorderRadius.circular(20.0),
      onTap: () {
        // Trigger the Disclaimer Confirmation Dialog
        final targetTheme = isDark ? SanctuaryTheme.light : SanctuaryTheme.dark;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PermanentThemeLockDialog(
            targetTheme: targetTheme,
            onConfirm: () {
              ref.read(themeProvider.notifier).switchAndLockTheme(targetTheme);
              Navigator.of(ctx).pop();
            },
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2923) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isDark ? const Color(0xFF263830) : const Color(0xFFEBE6DC),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              size: 14.0,
              color: isDark ? const Color(0xFFE27D60) : const Color(0xFF17382B),
            ),
            const SizedBox(width: 6.0),
            Text(
              isDark ? "Dark Mode" : "Light Mode",
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF15221C),
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(Icons.keyboard_arrow_down, size: 14.0, color: isDark ? Colors.white54 : Colors.black45),
          ],
        ),
      ),
    );
  }
}
6. PERMANENT THEME LOCK CONFIRMATION DIALOG
Jab user mode switch karne ke liye tap karta hai, to ye dialog irrevocable consent warn karta hai:

Dart


// lib/core/theme/widgets/permanent_theme_lock_dialog.dart
import 'package:flutter/material.dart';
import '../theme_controller.dart';

class PermanentThemeLockDialog extends StatelessWidget {
  final SanctuaryTheme targetTheme;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PermanentThemeLockDialog({
    Key? key,
    required this.targetTheme,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSwitchingToDark = (targetTheme == SanctuaryTheme.dark);

    return Dialog(
      backgroundColor: isSwitchingToDark ? const Color(0xFF1B2923) : const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSwitchingToDark ? Icons.dark_mode : Icons.light_mode,
              size: 44.0,
              color: isSwitchingToDark ? const Color(0xFFE27D60) : const Color(0xFF17382B),
            ),
            const SizedBox(height: 16.0),
            Text(
              "Permanent Visual Sanctuary",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: isSwitchingToDark ? Colors.white : const Color(0xFF15221C),
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              "Important Notice: UR-Heart enforces an unhurried, permanent visual mode. "
              "If you switch to ${isSwitchingToDark ? 'Dark Sanctuary' : 'Light Sanctuary'}, "
              "this display mode will be permanently locked on this device. "
              "You will NEVER be able to change this setting again across the entire app.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isSwitchingToDark ? Colors.white70 : const Color(0xFF4A5851),
              ),
            ),
            const SizedBox(height: 24.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      side: BorderSide(
                        color: isSwitchingToDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    onPressed: onCancel,
                    child: Text(
                      "Keep Current",
                      style: TextStyle(
                        color: isSwitchingToDark ? Colors.white70 : const Color(0xFF4A5851),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSwitchingToDark ? const Color(0xFFE27D60) : const Color(0xFF17382B),
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    onPressed: onConfirm,
                    child: const Text(
                      "Confirm & Lock",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
7. REUSABLE ATOMIC STITCH COMPONENTS
7.1 Mindful Primary Action Button
Dark mode mein Coral (#E27D60)[cite: 2, 3] aur Light mode mein Forest Pine (#17382B)[cite: 15, 28] button render hota hai:

Dart


class MindfulButton extends ConsumerWidget {
  final String label;
  final VoidCallback onPressed;
  final bool hasArrow;

  const MindfulButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.hasArrow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    return Container(
      width: double.infinity,
      height: 56.0,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFFE27D60) : const Color(0xFF17382B),
        borderRadius: BorderRadius.circular(28.0),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33E27D60) : const Color(0x2217382B),
            blurRadius: 16.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28.0),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasArrow) ...[
                  const SizedBox(width: 8.0),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 18.0),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
7.2 Statutory Mindful Checkbox Tile (Screen 1 & 21)
Unbundled consent checkboxes exactly Stitch aesthetic follow karte hain (rounded corners, delicate check indicator)[cite: 2, 15, 28]:

Dart


class MindfulCheckboxTile extends ConsumerWidget {
  final bool value;
  final Widget richTextContent;
  final ValueChanged<bool> onChanged;

  const MindfulCheckboxTile({
    Key? key,
    required this.value,
    required this.richTextContent,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22.0,
              height: 22.0,
              margin: const EdgeInsets.only(top: 2.0, right: 12.0),
              decoration: BoxDecoration(
                color: value
                    ? (isDark ? const Color(0xFFE27D60) : const Color(0xFF17382B))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(
                  color: value
                      ? (isDark ? const Color(0xFFE27D60) : const Color(0xFF17382B))
                      : (isDark ? Colors.white30 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 15.0, color: Colors.white)
                  : null,
            ),
            Expanded(child: richTextContent),
          ],
        ),
      ),
    );
  }
}
8. ANTIGRAVITY VERIFICATION & COMPLIANCE CHECKLIST
Antigravity agent ko theme engine verify karte waqt nimn specifications check karni hain:

Default Light Installation Test: Verify karein ki app fresh install hone par SharedPreferences empty hone par automatically Light Theme (#F9F7F2) mein load ho rahi hai[cite: 15, 28].

Top Header Pill Verification: Confirm karein ki Screen 1 ke top header par English ▾ ki jagah ThemeSelectorPill (Light Mode ▾) render ho raha hai[cite: 28].

Modal Warning Trigger: Header pill tap karne par permanent lock warning dialog pop-up hona chahiye.

Irrevocable Lockdown Assertion: Ek baar "Confirm & Lock" tap hone ke baad ya Screen 1 ke "I Agree & Continue" proceed hone ke baad verify karein ki header pill static ho jata hai aur settings screen par koi theme switcher exist nahi karta.   
PNG
+ 2


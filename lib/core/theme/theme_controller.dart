import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SanctuaryThemeMode { light, dark }
typedef SanctuaryTheme = SanctuaryThemeMode;

class ThemeState {
  final SanctuaryThemeMode mode;
  final bool isLocked;

  const ThemeState({
    SanctuaryThemeMode? mode,
    SanctuaryThemeMode? activeTheme,
    required this.isLocked,
  }) : mode = mode ?? activeTheme ?? SanctuaryThemeMode.light;

  SanctuaryThemeMode get activeTheme => mode;

  ThemeState copyWith({
    SanctuaryThemeMode? mode,
    SanctuaryThemeMode? activeTheme,
    bool? isLocked,
  }) {
    return ThemeState(
      mode: mode ?? activeTheme ?? this.mode,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeState &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          isLocked == other.isLocked;

  @override
  int get hashCode => mode.hashCode ^ isLocked.hashCode;
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>((ref) {
  return ThemeController();
});

final themeProvider = themeControllerProvider;

class ThemeController extends StateNotifier<ThemeState> {
  static const String _themeKey = 'urheart_theme_mode';
  static const String _lockKey = 'urheart_theme_permanently_locked';
  static const String legacyThemeKey = 'ur_heart_theme_mode';
  static const String legacyLockKey = 'ur_heart_theme_locked';

  ThemeController([ThemeState? initialState])
      : super(initialState ??
            const ThemeState(mode: SanctuaryThemeMode.light, isLocked: false)) {
    if (initialState == null) {
      loadThemeFromPersistence();
    }
  }

  Future<void> loadThemeFromPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    final isLocked = (prefs.getBool(_lockKey) ?? prefs.getBool(legacyLockKey)) ?? false;
    final savedMode = prefs.getString(_themeKey) ?? prefs.getString(legacyThemeKey);

    SanctuaryThemeMode mode = SanctuaryThemeMode.light;
    if (savedMode == 'dark') {
      mode = SanctuaryThemeMode.dark;
    }

    state = ThemeState(mode: mode, isLocked: isLocked);
  }

  void switchDraftMode(SanctuaryThemeMode newMode) {
    if (state.isLocked) return;
    state = state.copyWith(mode: newMode);
  }

  Future<void> lockThemePermanently() async {
    if (state.isLocked) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, state.mode.name);
    await prefs.setBool(_lockKey, true);
    await prefs.setString(legacyThemeKey, state.mode.name);
    await prefs.setBool(legacyLockKey, true);
    state = state.copyWith(isLocked: true);
  }

  Future<void> switchAndLockTheme(SanctuaryThemeMode newTheme) async {
    if (state.isLocked) return;
    switchDraftMode(newTheme);
    await lockThemePermanently();
  }

  Future<void> lockCurrentThemePermanently() async {
    await lockThemePermanently();
  }

  Future<void> resetThemeLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
    await prefs.remove(_lockKey);
    await prefs.remove(legacyThemeKey);
    await prefs.remove(legacyLockKey);
    state = const ThemeState(mode: SanctuaryThemeMode.light, isLocked: false);
  }
}

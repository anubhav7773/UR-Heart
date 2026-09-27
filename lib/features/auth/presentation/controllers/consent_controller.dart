import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';

/// Immutable state for Screen 1 Mindful Consent
class ConsentState {
  final bool isAgeConfirmed;
  final bool isDpdpConsented;

  const ConsentState({
    this.isAgeConfirmed = false,
    this.isDpdpConsented = false,
  });

  bool get canProceed => isAgeConfirmed && isDpdpConsented;

  ConsentState copyWith({
    bool? isAgeConfirmed,
    bool? isDpdpConsented,
  }) {
    return ConsentState(
      isAgeConfirmed: isAgeConfirmed ?? this.isAgeConfirmed,
      isDpdpConsented: isDpdpConsented ?? this.isDpdpConsented,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentState &&
          runtimeType == other.runtimeType &&
          isAgeConfirmed == other.isAgeConfirmed &&
          isDpdpConsented == other.isDpdpConsented;

  @override
  int get hashCode => isAgeConfirmed.hashCode ^ isDpdpConsented.hashCode;
}

/// Controller managing legal consent affirmations and irrevocable theme lock
class ConsentController extends StateNotifier<ConsentState> {
  final Ref _ref;

  ConsentController(this._ref) : super(const ConsentState());

  void toggleAgeConfirmed(bool value) {
    state = state.copyWith(isAgeConfirmed: value);
  }

  void toggleDpdpConsented(bool value) {
    state = state.copyWith(isDpdpConsented: value);
  }

  /// Irrevocably locks the current theme and commits consent
  Future<bool> submitConsent() async {
    if (!state.canProceed) {
      return false;
    }
    // Lock current theme permanently upon onboarding consent
    await _ref.read(themeProvider.notifier).lockCurrentThemePermanently();
    return true;
  }
  Future<bool> persistConsent() async {
    return submitConsent();
  }
}

/// Provider for Screen 1 consent state
final consentProvider =
    StateNotifierProvider<ConsentController, ConsentState>((ref) {
  return ConsentController(ref);
});

final consentControllerProvider = consentProvider;

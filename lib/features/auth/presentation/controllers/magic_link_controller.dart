import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MagicLinkState {
  final int cooldownSeconds;
  final bool isVerifying;
  final bool isVerified;
  final String? deepLinkError;

  const MagicLinkState({
    this.cooldownSeconds = 45,
    this.isVerifying = false,
    this.isVerified = false,
    this.deepLinkError,
  });

  bool get canResend => cooldownSeconds <= 0;

  MagicLinkState copyWith({
    int? cooldownSeconds,
    bool? isVerifying,
    bool? isVerified,
    String? deepLinkError,
  }) {
    return MagicLinkState(
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      isVerifying: isVerifying ?? this.isVerifying,
      isVerified: isVerified ?? this.isVerified,
      deepLinkError: deepLinkError ?? this.deepLinkError,
    );
  }
}

class MagicLinkController extends StateNotifier<MagicLinkState> {
  Timer? _timer;

  MagicLinkController() : super(const MagicLinkState()) {
    startCooldown(45);
  }

  void startCooldown([int seconds = 45]) {
    _timer?.cancel();
    state = state.copyWith(cooldownSeconds: seconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.cooldownSeconds > 1) {
        state = state.copyWith(cooldownSeconds: state.cooldownSeconds - 1);
      } else {
        state = state.copyWith(cooldownSeconds: 0);
        timer.cancel();
      }
    });
  }

  Future<bool> handleDeepLinkUrl(String url) async {
    state = state.copyWith(isVerifying: true);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (url.contains('token=') || url.contains('urheart.app/auth')) {
      state = state.copyWith(isVerifying: false, isVerified: true);
      return true;
    }

    state = state.copyWith(
      isVerifying: false,
      deepLinkError: 'Invalid or expired magic sanctuary link',
    );
    return false;
  }

  Future<bool> launchEmailApp() async {
    // Native email app launcher hook
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final magicLinkControllerProvider =
    StateNotifierProvider<MagicLinkController, MagicLinkState>((ref) {
  return MagicLinkController();
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/crypto/sanctuary_crypto_vault.dart';
import '../../data/settings_repository.dart';
import '../../../growth/data/slumber_sensor_service.dart';

/// Centralized Action Handlers for Sanctuary Settings & Governance (ACT-04, ACT-06, ACT-07, ACT-15, ACT-16, ACT-17 Fix)
class SettingsActionHandlers {
  /// ACT-04 FIX: Irrevocable Account Incinerator with Strict Confirmation
  static Future<void> handleAccountIncineration({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    try {
      final success = await ref.read(settingsRepositoryProvider).incinerateAccountIrrevocably();
      if (success && context.mounted) {
        // Clear all session states and redirect to root entry
        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erasure aborted: ${e.toString()}')),
        );
      }
    }
  }

  /// ACT-06 FIX: Night Slumber Mode Persistence & Sensor Hook
  static Future<void> handleSlumberToggle({
    required WidgetRef ref,
    required bool isActive,
  }) async {
    await ref.read(settingsRepositoryProvider).updateSlumberMode(isActive);
    if (isActive) {
      SlumberSensorService.instance.startHardwareMonitoring();
    } else {
      SlumberSensorService.instance.stopHardwareMonitoring();
    }
  }

  /// ACT-07 FIX: Native OS Referral Share Sheet
  static Future<void> handleReferralShare({
    required String referralCode,
  }) async {
    final text = 'Join me in the quiet presence of UR-Heart Dating Sanctuary. '
        'Enter with my passage crest: $referralCode\nhttps://urheart.app/join/$referralCode';
    await Share.share(text, subject: 'UR-Heart Sanctuary Invitation');
  }

  /// ACT-15 & ACT-16 FIX: Incognito Stealth & Discreet Mode Sync
  static Future<void> handlePreferencesToggle({
    required WidgetRef ref,
    bool? isIncognito,
    bool? isDiscreet,
  }) async {
    await ref.read(settingsRepositoryProvider).updateUserPreferences(
      isIncognito: isIncognito,
      isDiscreet: isDiscreet,
    );
  }

  /// ACT-17 FIX: Cryptographic X25519 Key Rotation
  static Future<void> handleKeyRotation({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    try {
      // 1. Generate genuine new X25519 keypair
      final pubKeyBase64 = await SanctuaryCryptoVault.instance.rotateLocalKeyPair();

      // 2. Register with backend registry
      final success = await ref.read(settingsRepositoryProvider).registerRotatedPublicKey(pubKeyBase64);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('X25519 session keys rotated and registered in Sanctuary vault.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cryptographic key rotation failed.')),
        );
      }
    }
  }
}

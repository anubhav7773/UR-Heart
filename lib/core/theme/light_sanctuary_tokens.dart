import 'package:flutter/material.dart';
import 'sanctuary_colors.dart';

/// Light Sanctuary Design Tokens (Docs 14 & 16)
class LightSanctuaryTokens {
  const LightSanctuaryTokens._();

  static const Color background = SanctuaryColors.warmCream;
  static const Color surface = SanctuaryColors.pureWhite;
  static const Color surfaceMuted = SanctuaryColors.softBeige;
  static const Color primaryText = SanctuaryColors.deepCharcoal;
  static const Color secondaryText = SanctuaryColors.mutedSlate;
  static const Color accentTerracotta = SanctuaryColors.warmTerracotta;
  static const Color sanctuaryPine = SanctuaryColors.sanctuaryPine;
  static const Color goldAccent = SanctuaryColors.sacredGold;
  static const Color dangerBorder = SanctuaryColors.alertCrimson;
  static const Color cardShadow = SanctuaryColors.subtleShadow;

  // Semantic & Screen Integration Aliases
  static const Color surfaceCard = surface;
  static const Color surfaceCardBorder = surfaceMuted;
  static const Color bottomNavBackground = surface;
  static const Color chipBackground = Color(0xFFF2EFE9);
  static const Color verifiedBadge = Color(0xFF2B8A6E);
  static const Color accentGold = goldAccent;
  static const Color primaryPine = sanctuaryPine;
  static const Color primaryPineGlow = Color(0x222D5A43);
  static const Color terracottaAccent = accentTerracotta;

  // Typography Tokens
  static const Color textHeadline = primaryText;
  static const Color textHeadlineItalic = accentTerracotta;
  static const Color textBody = Color(0xFF4A5851);
  static const Color textMuted = secondaryText;
  static const Color textLegalNotice = Color(0xFF8F9C95);

  // Inputs, Dialogues & Sentinel
  static const Color inputBackground = Color(0xFFF7F5F0);
  static const Color inputBorder = Color(0xFFE4DFD5);
  static const Color checkboxActive = sanctuaryPine;
  static const Color chatBubbleSender = sanctuaryPine;
  static const Color chatBubbleReceiver = surface;
  static const Color chatBubbleReceiverBorder = surfaceMuted;
  static const Color tickGrey = secondaryText;
  static const Color tickBlue = SanctuaryColors.tickCyan;
  static const Color badgeOnline = SanctuaryColors.onlineEmerald;
  static const Color badgeWaKey = SanctuaryColors.onlineEmerald;
  static const Color alertBanner = Color(0x22C85A32);
  static const Color alertBannerBorder = accentTerracotta;
  static const Color warningText = accentTerracotta;
  static const Color crimsonDelete = dangerBorder;
  static const Color crimsonDeleteBorder = Color(0x66DC2626);
  static const Color crimsonDeleteBackground = Color(0x1ADC2626);
  static const Color superadminGold = goldAccent;
  static const Color superadminGoldBorder = Color(0xFFB8972E);
  static const Color superadminGoldGlow = Color(0x33D4AF37);
}

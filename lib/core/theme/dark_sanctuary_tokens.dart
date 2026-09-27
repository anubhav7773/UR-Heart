import 'package:flutter/material.dart';
import 'sanctuary_colors.dart';

/// Dark Sanctuary Design Tokens (Docs 14 & 16)
class DarkSanctuaryTokens {
  const DarkSanctuaryTokens._();

  static const Color background = SanctuaryColors.midnightObsidian;
  static const Color surface = SanctuaryColors.elevatedSlate;
  static const Color surfaceMuted = SanctuaryColors.mutedCharcoalBorder;
  static const Color primaryText = SanctuaryColors.crispIvory;
  static const Color secondaryText = SanctuaryColors.softGreySubtext;
  static const Color accentTerracotta = SanctuaryColors.glowingTerracotta;
  static const Color sanctuaryPine = SanctuaryColors.mutedEmeraldPine;
  static const Color goldAccent = SanctuaryColors.resonantGold;
  static const Color dangerBorder = SanctuaryColors.alertRed;
  static const Color cardShadow = SanctuaryColors.deepAmbientShadow;

  // Semantic & Screen Integration Aliases
  static const Color surfaceCard = surface;
  static const Color surfaceCardBorder = surfaceMuted;
  static const Color bottomNavBackground = Color(0xFF0D1612);
  static const Color primaryCoral = accentTerracotta;
  static const Color primaryCoralGlow = Color(0x33D97746);
  static const Color secondaryPine = sanctuaryPine;
  static const Color accentGold = goldAccent;
  static const Color verifiedBadge = SanctuaryColors.onlineEmerald;

  // Typography Tokens
  static const Color textHeadline = primaryText;
  static const Color textHeadlineItalic = accentTerracotta;
  static const Color textBody = Color(0xFFD8E2DC);
  static const Color textMuted = secondaryText;
  static const Color textLegalNotice = Color(0xFF6B7C72);

  // Inputs, Dialogues & Sentinel
  static const Color inputBackground = Color(0xFF131F19);
  static const Color inputBorder = Color(0xFF22362C);
  static const Color checkboxActive = accentTerracotta;
  static const Color chatBubbleSender = sanctuaryPine;
  static const Color chatBubbleReceiver = surface;
  static const Color chatBubbleReceiverBorder = surfaceMuted;
  static const Color tickGrey = secondaryText;
  static const Color tickBlue = SanctuaryColors.tickCyan;
  static const Color badgeOnline = SanctuaryColors.onlineEmerald;
  static const Color badgeWaKey = SanctuaryColors.onlineEmerald;
  static const Color alertBanner = Color(0x33D97746);
  static const Color alertBannerBorder = accentTerracotta;
  static const Color warningText = accentTerracotta;
  static const Color crimsonDelete = dangerBorder;
  static const Color crimsonDeleteBorder = Color(0x66EF4444);
  static const Color crimsonDeleteBackground = Color(0x1AEF4444);
  static const Color superadminGold = goldAccent;
  static const Color superadminGoldBorder = Color(0xFFD4AF37);
  static const Color superadminGoldGlow = Color(0x33E5C158);
}

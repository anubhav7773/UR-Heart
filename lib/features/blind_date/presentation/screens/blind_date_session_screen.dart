import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/rewarded_ad_manager.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/sanctuary_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../chat/presentation/screens/chat_dialogue_screen.dart';
import '../../../chat/presentation/services/window_security_service.dart';
import '../../../feed/presentation/widgets/voice_spark_pill.dart';
import '../controllers/blind_date_controller.dart';
import '../../domain/blind_date_models.dart';

class BlindDateSessionScreen extends ConsumerStatefulWidget {
  static const String routeName = '/blind-date-session';

  const BlindDateSessionScreen({super.key});

  @override
  ConsumerState<BlindDateSessionScreen> createState() =>
      _BlindDateSessionScreenState();
}

class _BlindDateSessionScreenState extends ConsumerState<BlindDateSessionScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasPromptedCelebration = false;

  @override
  void initState() {
    super.initState();
    _enforceWindowSecurity();
  }

  Future<void> _enforceWindowSecurity() async {
    // DPDP Act 2023 Statutory Privacy Shield
    final isBypassed = await WindowSecurityService.isBypassedUser();
    if (!isBypassed) {
      await WindowSecurityService.enableSecureMode();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Reapply default navigation tab policy
    WindowSecurityService.applyPolicyForTab(
        WindowSecurityService.currentShellTab);
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blindDateControllerProvider);
    final controller = ref.read(blindDateControllerProvider.notifier);
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState.authenticatedUserId ?? '';
    final session = state.session;
    final partner = session?.partner;

    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;
    final bgColor = isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background;
    final surfaceColor = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final surfaceMutedColor = isDark ? DarkSanctuaryTokens.surfaceMuted : LightSanctuaryTokens.surfaceMuted;
    final primaryTextColor = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final secondaryTextColor = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final accentColor = isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.accentTerracotta;
    final goldColor = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;

    // Trigger celebration dialog on mutual resonance
    if (session != null &&
        session.status == 'revealed' &&
        !_hasPromptedCelebration) {
      _hasPromptedCelebration = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMutualResonanceDialog(
          context,
          partner,
          session.matchId,
          isDark: isDark,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          accentColor: accentColor,
        );
      });
    }

    final isExpired =
        session?.status == 'expired' || state.remainingSeconds <= 0;
    final isPassed = session?.status == 'passed';
    final isRevealed = session?.status == 'revealed';
    final canChat = !isExpired && !isPassed;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryTextColor),
          onPressed: () {
            controller.resetSession();
            Navigator.of(context).maybePop();
          },
        ),
        title: _buildTimerBadge(
          context,
          state.remainingSeconds,
          isExpired,
          canChat,
          controller,
          currentUserId,
          isDark: isDark,
          surfaceColor: surfaceColor,
          surfaceMutedColor: surfaceMutedColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          accentColor: accentColor,
          goldColor: goldColor,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined,
                color: SanctuaryColors.onlineEmerald, size: 20),
            tooltip: 'DPDP Privacy Shield Active',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Protected by DPDP Act 2023: Screenshots & Recordings Blocked',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: Masked Seeker Profile & Eva Icebreaker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildVeiledPartnerCard(
                partner,
                isRevealed,
                isDark: isDark,
                surfaceColor: surfaceColor,
                surfaceMutedColor: surfaceMutedColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                accentColor: accentColor,
              ),
            ),

            if (session?.icebreakerPrompt != null &&
                session!.icebreakerPrompt.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildEvaIcebreakerBanner(
                  session.icebreakerPrompt,
                  isDark: isDark,
                  goldColor: goldColor,
                ),
              ),

            Divider(
              color: surfaceMutedColor,
              height: 16,
              thickness: 1,
            ),

            // Live Ephemeral Chat Stream
            Expanded(
              child: state.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 40,
                            color: secondaryTextColor.withAlpha(120),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Begin your 5-minute blind dialogue...',
                            style: TextStyle(
                              color: secondaryTextColor.withAlpha(160),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final msg = state.messages[index];
                        return _buildChatBubble(
                          msg,
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          surfaceMutedColor: surfaceMutedColor,
                          primaryTextColor: primaryTextColor,
                          accentColor: accentColor,
                        );
                      },
                    ),
            ),

            // In-Session +3 Minute Extension Prompt (when <= 60s remaining)
            if (canChat && state.remainingSeconds <= 60 && (session?.extensionCount ?? 0) < 3)
              _buildExtensionPrompt(
                context,
                state,
                controller,
                currentUserId,
                isDark: isDark,
                surfaceColor: surfaceColor,
                surfaceMutedColor: surfaceMutedColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                accentColor: accentColor,
                goldColor: goldColor,
              ),

            // Chat Input Bar (if session still active)
            if (canChat)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(
                    top: BorderSide(
                      color: surfaceMutedColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: primaryTextColor),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Share a gentle thought...',
                          hintStyle: TextStyle(
                            color: secondaryTextColor.withAlpha(160),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(controller),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: accentColor,
                      ),
                      onPressed: () => _sendMessage(controller),
                    ),
                  ],
                ),
              ),

            // Bottom Resonance Gate
            _buildResonanceGateBar(
              context,
              state,
              controller,
              isDark: isDark,
              surfaceColor: surfaceColor,
              surfaceMutedColor: surfaceMutedColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              accentColor: accentColor,
              goldColor: goldColor,
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(BlindDateController controller) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    controller.sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  Widget _buildExtensionPrompt(
    BuildContext context,
    BlindDateState state,
    BlindDateController controller,
    String userId, {
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceMutedColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color accentColor,
    required Color goldColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: goldColor.withAlpha(isDark ? 30 : 25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldColor.withAlpha(isDark ? 120 : 160)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom_rounded, size: 18, color: goldColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Veil closing soon! Extend dialogue (+3 Mins)?',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: state.isExtending
                ? null
                : () => _showExtensionDialog(
                      context,
                      controller,
                      userId,
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      surfaceMutedColor: surfaceMutedColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      accentColor: accentColor,
                      goldColor: goldColor,
                    ),
            style: TextButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: state.isExtending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '+3 Mins',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBadge(
    BuildContext context,
    int seconds,
    bool isExpired,
    bool canChat,
    BlindDateController controller,
    String userId, {
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceMutedColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color accentColor,
    required Color goldColor,
  }) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final isLowTime = seconds <= 60 && !isExpired;

    final badgeColor = isExpired
        ? SanctuaryColors.alertRed.withAlpha(isDark ? 30 : 25)
        : isLowTime
            ? goldColor.withAlpha(isDark ? 40 : 25)
            : surfaceColor;

    final badgeBorderColor = isExpired
        ? SanctuaryColors.alertRed
        : isLowTime
            ? goldColor
            : surfaceMutedColor;

    final badgeTextColor = isExpired
        ? SanctuaryColors.alertRed
        : isLowTime
            ? goldColor
            : primaryTextColor;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: 16,
            color: badgeTextColor,
          ),
          const SizedBox(width: 6),
          Text(
            isExpired ? 'Session Expired' : '$mm:$ss',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: badgeTextColor,
              letterSpacing: 0.5,
            ),
          ),
          if (isLowTime && canChat) ...[
            const SizedBox(width: 6),
            Text(
              '• +3m',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: goldColor,
              ),
            ),
          ],
        ],
      ),
    );

    if (isLowTime && canChat) {
      return InkWell(
        onTap: () => _showExtensionDialog(
          context,
          controller,
          userId,
          isDark: isDark,
          surfaceColor: surfaceColor,
          surfaceMutedColor: surfaceMutedColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          accentColor: accentColor,
          goldColor: goldColor,
        ),
        borderRadius: BorderRadius.circular(20),
        child: badge,
      );
    }

    return badge;
  }

  Widget _buildVeiledPartnerCard(
    BlindDatePartner? partner,
    bool isRevealed, {
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceMutedColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color accentColor,
  }) {
    final name = partner?.name ?? 'Soul Seeker';
    final age = partner?.age ?? 24;
    final location = partner?.location ?? 'Sanctuary';
    final hasVoice = partner?.voiceSparkUrl != null &&
        partner!.voiceSparkUrl!.trim().isNotEmpty;

    final fallbackPlaceholderBg = isDark
        ? DarkSanctuaryTokens.background
        : const Color(0xFFECE6DC);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRevealed
              ? accentColor
              : surfaceMutedColor,
          width: isRevealed ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Masked / Veiled Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isRevealed &&
                          partner?.photos.isNotEmpty == true)
                        Image.network(
                          partner!.photos.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: fallbackPlaceholderBg),
                        )
                      else ...[
                        Container(
                          color: fallbackPlaceholderBg,
                          child: Icon(
                            Icons.person,
                            size: 34,
                            color: secondaryTextColor,
                          ),
                        ),
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
                          child: Container(
                            color: Colors.black.withAlpha(isDark ? 50 : 25),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$name, $age',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isRevealed) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: SanctuaryColors.onlineEmerald,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          location,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isRevealed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(isDark ? 30 : 20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Veiled',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          // Voice Spark integration if seeker recorded one
          if (hasVoice) ...[
            const SizedBox(height: 10),
            VoiceSparkPill(
              voiceUrl: partner.voiceSparkUrl!,
              prompt: partner.voiceSparkPrompt,
              duration: partner.voiceSparkDuration,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvaIcebreakerBanner(
    String prompt, {
    required bool isDark,
    required Color goldColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? DarkSanctuaryTokens.background : const Color(0xFFFAF7EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: goldColor.withAlpha(isDark ? 60 : 90),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 16,
            color: goldColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '"$prompt"',
              style: TextStyle(
                color: isDark ? goldColor : const Color(0xFF8A6D1B),
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(
    BlindDateMessageModel msg, {
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceMutedColor,
    required Color primaryTextColor,
    required Color accentColor,
  }) {
    final isMe = msg.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? accentColor
              : surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe
              ? null
              : Border.all(color: surfaceMutedColor),
        ),
        child: Text(
          msg.ciphertext,
          style: TextStyle(
            color: isMe ? Colors.white : primaryTextColor,
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildResonanceGateBar(
    BuildContext context,
    BlindDateState state,
    BlindDateController controller, {
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceMutedColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color accentColor,
    required Color goldColor,
  }) {
    final session = state.session;
    final myDecision = session?.myDecision ?? 'pending';
    final isRevealed = session?.status == 'revealed';
    final isPassed = session?.status == 'passed';

    if (isRevealed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: surfaceColor,
        child: ElevatedButton.icon(
          onPressed: () {
            final p = session?.partner;
            Navigator.of(context).pushReplacementNamed(
              ChatDialogueScreen.routeName,
              arguments: ChatDialogueArguments(
                matchId: session?.matchId ?? '',
                recipientId: p?.id ?? '',
                recipientName: p?.name ?? 'Soul Seeker',
                recipientAge: p?.age ?? 24,
                recipientAvatarUrl: p?.avatarUrl ??
                    (p?.photos.isNotEmpty == true ? p!.photos.first : ''),
                bio: p?.bio ?? '',
                location: p?.location ?? 'Sanctuary',
                gender: p?.gender ?? '',
              ),
            );
          },
          icon: const Icon(Icons.favorite, color: Colors.white),
          label: const Text(
            'Continue Dialogue in Direct Chat',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: SanctuaryColors.onlineEmerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    if (isPassed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: surfaceColor,
        child: Text(
          'Mindful Bow Completed • Session Gracefully Concluded',
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(
              color: surfaceMutedColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (myDecision == 'resonate')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: goldColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'You tapped Resonate. Awaiting soul counterpart...',
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Mindful Bow (Pass)
              Expanded(
                child: OutlinedButton(
                  onPressed: myDecision != 'pending'
                      ? null
                      : () => controller.pass(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: secondaryTextColor,
                    side: BorderSide(color: surfaceMutedColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Mindful Bow',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Resonate (Consent Gate)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: myDecision != 'pending'
                      ? null
                      : () => controller.resonate(),
                  icon: const Icon(Icons.favorite_border_rounded, size: 18),
                  label: const Text(
                    'Resonate',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMutualResonanceDialog(
    BuildContext context,
    BlindDatePartner? partner,
    String? matchId, {
    required bool isDark,
    required Color surfaceColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color accentColor,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: surfaceColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SanctuaryColors.onlineEmerald.withAlpha(isDark ? 30 : 25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 40,
                    color: SanctuaryColors.onlineEmerald,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mutual Resonance!',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Both of you resonated. The veil has lifted—${partner?.name ?? "your counterpart"} is now an active match.',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pushReplacementNamed(
                        ChatDialogueScreen.routeName,
                        arguments: ChatDialogueArguments(
                          matchId: matchId ?? '',
                          recipientId: partner?.id ?? '',
                          recipientName: partner?.name ?? 'Soul Seeker',
                          recipientAge: partner?.age ?? 24,
                          recipientAvatarUrl: partner?.avatarUrl ??
                              (partner?.photos.isNotEmpty == true
                                  ? partner!.photos.first
                                  : ''),
                          bio: partner?.bio ?? '',
                          location: partner?.location ?? 'Sanctuary',
                          gender: partner?.gender ?? '',
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Open Dialogue'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showExtensionDialog(
    BuildContext context,
    BlindDateController controller,
    String userId, {
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceMutedColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color accentColor,
    required Color goldColor,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: surfaceMutedColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: goldColor.withAlpha(isDark ? 40 : 25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hourglass_bottom_rounded,
                      color: goldColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Extend Soul Dialogue (+3 Mins)',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Equal Perks • Keep connection blossoming',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? DarkSanctuaryTokens.background : const Color(0xFFF7F5F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: surfaceMutedColor),
                ),
                child: Text(
                  'Extending adds +180 seconds to this veiled sanctuary so you can continue your soulful exchange without rushing.',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Option A: Watch 30s Ad (100% Free)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  RewardedAdManager.instance.showRewardedAd(
                    userId: userId,
                    adType: 'session_extension',
                    targetId: 'none',
                    context: context,
                    onRewardGranted: () async {
                      final success = await controller.extendSession();
                      if (context.mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🌟 +3 Minutes of soulful dialogue unlocked!'),
                            backgroundColor: SanctuaryColors.onlineEmerald,
                          ),
                        );
                      }
                    },
                    onPlaybackFailed: (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reflection paused: $err')),
                        );
                      }
                    },
                  );
                },
                icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                label: const Text(
                  'Watch 30s Reflection (+3 Mins Free)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Option B: Instant ₹29 Perk
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final success = await controller.extendSession();
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚡ +3 Minutes unlocked via ₹29 perk!'),
                      ),
                    );
                  }
                },
                icon: Icon(Icons.bolt_rounded, size: 20, color: goldColor),
                label: const Text(
                  'Unlock Instant +3 Mins (₹29)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryTextColor,
                  side: BorderSide(color: surfaceMutedColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


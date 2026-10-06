import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/rewarded_ad_manager.dart';
import '../../../../core/theme/sanctuary_colors.dart';
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

    // Trigger celebration dialog on mutual resonance
    if (session != null &&
        session.status == 'revealed' &&
        !_hasPromptedCelebration) {
      _hasPromptedCelebration = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMutualResonanceDialog(context, partner, session.matchId);
      });
    }

    final isExpired =
        session?.status == 'expired' || state.remainingSeconds <= 0;
    final isPassed = session?.status == 'passed';
    final isRevealed = session?.status == 'revealed';
    final canChat = !isExpired && !isPassed;

    return Scaffold(
      backgroundColor: SanctuaryColors.midnightObsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: SanctuaryColors.crispIvory),
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
              child: _buildVeiledPartnerCard(partner, isRevealed),
            ),

            if (session?.icebreakerPrompt != null &&
                session!.icebreakerPrompt.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildEvaIcebreakerBanner(session.icebreakerPrompt),
              ),

            const Divider(
              color: SanctuaryColors.mutedCharcoalBorder,
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
                            color:
                                SanctuaryColors.softGreySubtext.withAlpha(120),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Begin your 5-minute blind dialogue...',
                            style: TextStyle(
                              color: SanctuaryColors.softGreySubtext
                                  .withAlpha(160),
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
                        return _buildChatBubble(msg);
                      },
                    ),
            ),

            // In-Session +3 Minute Extension Prompt (when <= 60s remaining)
            if (canChat && state.remainingSeconds <= 60 && (session?.extensionCount ?? 0) < 3)
              _buildExtensionPrompt(context, state, controller, currentUserId),

            // Chat Input Bar (if session still active)
            if (canChat)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: SanctuaryColors.elevatedSlate,
                  border: Border(
                    top: BorderSide(
                        color: SanctuaryColors.mutedCharcoalBorder, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style:
                            const TextStyle(color: SanctuaryColors.crispIvory),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Share a gentle thought...',
                          hintStyle: TextStyle(
                            color:
                                SanctuaryColors.softGreySubtext.withAlpha(160),
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
                      icon: const Icon(
                        Icons.send_rounded,
                        color: SanctuaryColors.glowingTerracotta,
                      ),
                      onPressed: () => _sendMessage(controller),
                    ),
                  ],
                ),
              ),

            // Bottom Resonance Gate
            _buildResonanceGateBar(context, state, controller),
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
    String userId,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: SanctuaryColors.resonantGold.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SanctuaryColors.resonantGold.withAlpha(120)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom_rounded, size: 18, color: SanctuaryColors.resonantGold),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Veil closing soon! Extend dialogue (+3 Mins)?',
              style: TextStyle(
                color: SanctuaryColors.crispIvory,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: state.isExtending
                ? null
                : () => _showExtensionDialog(context, controller, userId),
            style: TextButton.styleFrom(
              backgroundColor: SanctuaryColors.glowingTerracotta,
              foregroundColor: SanctuaryColors.crispIvory,
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
                      color: SanctuaryColors.crispIvory,
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
    String userId,
  ) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final isLowTime = seconds <= 60 && !isExpired;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isExpired
            ? SanctuaryColors.alertRed.withAlpha(30)
            : isLowTime
                ? SanctuaryColors.resonantGold.withAlpha(40)
                : SanctuaryColors.elevatedSlate,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpired
              ? SanctuaryColors.alertRed
              : isLowTime
                  ? SanctuaryColors.resonantGold
                  : SanctuaryColors.mutedCharcoalBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: 16,
            color: isExpired
                ? SanctuaryColors.alertRed
                : isLowTime
                    ? SanctuaryColors.resonantGold
                    : SanctuaryColors.crispIvory,
          ),
          const SizedBox(width: 6),
          Text(
            isExpired ? 'Session Expired' : '$mm:$ss',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isExpired
                  ? SanctuaryColors.alertRed
                  : isLowTime
                      ? SanctuaryColors.resonantGold
                      : SanctuaryColors.crispIvory,
              letterSpacing: 0.5,
            ),
          ),
          if (isLowTime && canChat) ...[
            const SizedBox(width: 6),
            const Text(
              '• +3m',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: SanctuaryColors.resonantGold,
              ),
            ),
          ],
        ],
      ),
    );

    if (isLowTime && canChat) {
      return InkWell(
        onTap: () => _showExtensionDialog(context, controller, userId),
        borderRadius: BorderRadius.circular(20),
        child: badge,
      );
    }

    return badge;
  }


  Widget _buildVeiledPartnerCard(
      BlindDatePartner? partner, bool isRevealed) {
    final name = partner?.name ?? 'Soul Seeker';
    final age = partner?.age ?? 24;
    final location = partner?.location ?? 'Sanctuary';
    final hasVoice = partner?.voiceSparkUrl != null &&
        partner!.voiceSparkUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SanctuaryColors.elevatedSlate,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRevealed
              ? SanctuaryColors.glowingTerracotta
              : SanctuaryColors.mutedCharcoalBorder,
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
                              Container(color: SanctuaryColors.midnightObsidian),
                        )
                      else ...[
                        Container(
                          color: SanctuaryColors.midnightObsidian,
                          child: const Icon(
                            Icons.person,
                            size: 34,
                            color: SanctuaryColors.softGreySubtext,
                          ),
                        ),
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
                          child: Container(
                            color: Colors.black.withAlpha(50),
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
                          style: const TextStyle(
                            color: SanctuaryColors.crispIvory,
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
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: SanctuaryColors.softGreySubtext,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          location,
                          style: const TextStyle(
                            color: SanctuaryColors.softGreySubtext,
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
                    color: SanctuaryColors.glowingTerracotta.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Veiled',
                    style: TextStyle(
                      color: SanctuaryColors.glowingTerracotta,
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
              isDark: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvaIcebreakerBanner(String prompt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SanctuaryColors.midnightObsidian,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SanctuaryColors.resonantGold.withAlpha(60),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 16,
            color: SanctuaryColors.resonantGold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '"$prompt"',
              style: const TextStyle(
                color: SanctuaryColors.resonantGold,
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

  Widget _buildChatBubble(BlindDateMessageModel msg) {
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
              ? SanctuaryColors.glowingTerracotta
              : SanctuaryColors.elevatedSlate,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe
              ? null
              : Border.all(color: SanctuaryColors.mutedCharcoalBorder),
        ),
        child: Text(
          msg.ciphertext,
          style: TextStyle(
            color: isMe ? Colors.white : SanctuaryColors.crispIvory,
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
    BlindDateController controller,
  ) {
    final session = state.session;
    final myDecision = session?.myDecision ?? 'pending';
    final isRevealed = session?.status == 'revealed';
    final isPassed = session?.status == 'passed';

    if (isRevealed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: SanctuaryColors.elevatedSlate,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(
              ChatDialogueScreen.routeName,
              arguments: {'partner_id': session?.partner?.id},
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
        color: SanctuaryColors.elevatedSlate,
        child: const Text(
          'Mindful Bow Completed • Session Gracefully Concluded',
          style: TextStyle(
            color: SanctuaryColors.softGreySubtext,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: SanctuaryColors.elevatedSlate,
        border: Border(
          top: BorderSide(
              color: SanctuaryColors.mutedCharcoalBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (myDecision == 'resonate')
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SanctuaryColors.resonantGold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'You tapped Resonate. Awaiting soul counterpart...',
                    style: TextStyle(
                      color: SanctuaryColors.resonantGold,
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
                    foregroundColor: SanctuaryColors.softGreySubtext,
                    side: const BorderSide(
                        color: SanctuaryColors.mutedCharcoalBorder),
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
                    backgroundColor: SanctuaryColors.glowingTerracotta,
                    foregroundColor: SanctuaryColors.crispIvory,
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
    String? matchId,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: SanctuaryColors.midnightObsidian,
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
                    color: SanctuaryColors.onlineEmerald.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 40,
                    color: SanctuaryColors.onlineEmerald,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mutual Resonance!',
                  style: TextStyle(
                    color: SanctuaryColors.crispIvory,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Both of you resonated. The veil has lifted—${partner?.name ?? "your counterpart"} is now an active match.',
                  style: const TextStyle(
                    color: SanctuaryColors.softGreySubtext,
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
                        arguments: {'partner_id': partner?.id},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SanctuaryColors.glowingTerracotta,
                      foregroundColor: SanctuaryColors.crispIvory,
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
    String userId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SanctuaryColors.elevatedSlate,
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
                    color: SanctuaryColors.mutedCharcoalBorder,
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
                      color: SanctuaryColors.resonantGold.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_bottom_rounded,
                      color: SanctuaryColors.resonantGold,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Extend Soul Dialogue (+3 Mins)',
                          style: TextStyle(
                            color: SanctuaryColors.crispIvory,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Equal Perks • Keep connection blossoming',
                          style: TextStyle(
                            color: SanctuaryColors.softGreySubtext,
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
                  color: SanctuaryColors.midnightObsidian,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SanctuaryColors.mutedCharcoalBorder),
                ),
                child: const Text(
                  'Extending adds +180 seconds to this veiled sanctuary so you can continue your soulful exchange without rushing.',
                  style: TextStyle(
                    color: SanctuaryColors.softGreySubtext,
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
                  backgroundColor: SanctuaryColors.glowingTerracotta,
                  foregroundColor: SanctuaryColors.crispIvory,
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
                icon: const Icon(Icons.bolt_rounded, size: 20, color: SanctuaryColors.resonantGold),
                label: const Text(
                  'Unlock Instant +3 Mins (₹29)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SanctuaryColors.crispIvory,
                  side: const BorderSide(color: SanctuaryColors.mutedCharcoalBorder),
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


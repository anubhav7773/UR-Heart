import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../data/chat_repository.dart';
import '../controllers/chat_dialogue_controller.dart';
import '../services/window_security_service.dart';
import '../widgets/ai_icebreaker_chips_row.dart';
import '../widgets/chat_safety_dialog.dart';
import '../widgets/dialogue_message_bubble.dart';
import '../widgets/nlp_warning_dialog.dart';
import '../widgets/sacred_bridge_app_bar_action.dart';
import '../widgets/shared_context_prompt_card.dart';
import '../widgets/text_only_chat_input_bar.dart';
import '../widgets/eva_bonding_spark_bar.dart';
import '../../../ai_sanctuary/presentation/widgets/ai_dialogue_coach_sheet.dart';
import '../../../../core/media/sanctuary_image_resolver.dart';
import '../../../profile/presentation/screens/seeker_profile_detail_screen.dart';

class ChatDialogueArguments {
  final String matchId, recipientId, recipientName, sharedContextQuote;
  final int recipientAge;
  final bool isOnline, hasWaKey;
  final String recipientAvatarUrl;
  final bool isVerified;
  final String bio;
  final String location;
  final List<String> interests;
  final String gender;

  const ChatDialogueArguments({
    required this.matchId,
    required this.recipientId,
    required this.recipientName,
    this.recipientAge = 25,
    this.isOnline = true,
    this.hasWaKey = false,
    this.recipientAvatarUrl = '',
    this.isVerified = false,
    this.bio = '',
    this.location = '',
    this.interests = const [],
    this.gender = '',
    this.sharedContextQuote = 'Sacred Mindful Dialogue',
  });
}

/// Screen 9: 1:1 Encrypted Dialogue Scaffold with FLAG_SECURE (< 210 lines)
class ChatDialogueScreen extends ConsumerStatefulWidget {
  final String? matchId;
  const ChatDialogueScreen({super.key, this.matchId});
  static const String routeName = '/chat-dialogue';

  @override
  ConsumerState<ChatDialogueScreen> createState() => _ChatDialogueScreenState();
}

class _ChatDialogueScreenState extends ConsumerState<ChatDialogueScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _chatInputController = TextEditingController();
  bool _isObscuredDueToFocusLoss = false;

  String _resolveMatchId() {
    final explicitId = widget.matchId;
    if (explicitId != null && explicitId.isNotEmpty) return explicitId;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is ChatDialogueArguments) return routeArgs.matchId;
    if (routeArgs is Map<String, dynamic>) {
      return routeArgs['match_id']?.toString() ?? 'match-aarav-1';
    }
    if (routeArgs is String && routeArgs.isNotEmpty) {
      return routeArgs;
    }
    return 'match-aarav-1';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      WindowSecurityService.enableSecureMode();
    } catch (_) {}

    Future.microtask(() {
      if (!mounted) return;
      final mId = _resolveMatchId();
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      final notifier = ref.read(chatDialogueControllerProvider(mId).notifier);
      if (routeArgs is ChatDialogueArguments) {
        notifier.setPeerProfile({
          'full_name': routeArgs.recipientName,
          'recipient_id': routeArgs.recipientId,
          'age': routeArgs.recipientAge,
          'is_online': routeArgs.isOnline,
          'avatar_url': routeArgs.recipientAvatarUrl,
          'recipient_avatar_url': routeArgs.recipientAvatarUrl,
          'is_verified': routeArgs.isVerified,
          'bio': routeArgs.bio,
          'location': routeArgs.location,
          'interests': routeArgs.interests,
          'gender': routeArgs.gender,
        });
      } else if (routeArgs is Map<String, dynamic>) {
        notifier.setPeerProfile({
          'full_name': routeArgs['partner_name'] ??
              routeArgs['peer_name'] ??
              routeArgs['name'],
          'recipient_id': routeArgs['partner_id'] ?? routeArgs['peer_id'],
          'avatar_url': routeArgs['partner_photo'] ??
              routeArgs['peer_photo'] ??
              routeArgs['recipient_avatar_url'] ??
              routeArgs['avatar_url'],
          'recipient_avatar_url': routeArgs['partner_photo'] ??
              routeArgs['peer_photo'] ??
              routeArgs['recipient_avatar_url'] ??
              routeArgs['avatar_url'],
          'age': routeArgs['partner_age'] ?? routeArgs['peer_age'] ?? routeArgs['age'],
          'is_verified': routeArgs['is_verified'] ??
              routeArgs['is_kyc_verified'] ??
              routeArgs['kyc_status'] ??
              false,
          'bio': routeArgs['bio'] ?? '',
          'location': routeArgs['location'] ?? routeArgs['city'] ?? '',
          'interests': routeArgs['interests'] ?? routeArgs['passions'] ?? <String>[],
          'gender': routeArgs['gender'] ?? '',
          'is_online': true,
        });
      }
      notifier.initializeDialogue();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) {
      final isInactive = state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden;
      if (_isObscuredDueToFocusLoss != isInactive && mounted) {
        setState(() {
          _isObscuredDueToFocusLoss = isInactive;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mId = _resolveMatchId();
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is ChatDialogueArguments ? routeArgs : null;

    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;
    final dialogueState = ref.watch(chatDialogueControllerProvider(mId));
    final notifier = ref.read(chatDialogueControllerProvider(mId).notifier);

    final bg = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final primaryText = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final subText =
        isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final pine = isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;

    final peer = dialogueState.peerProfile;
    final mapArgs = routeArgs is Map<String, dynamic> ? routeArgs : null;
    final fallbackName = mapArgs?['partner_name'] ??
        mapArgs?['peer_name'] ??
        mapArgs?['name'] ??
        peer['full_name'] ??
        'Mindful Seeker';
    final fallbackAge = mapArgs?['partner_age'] ??
        mapArgs?['peer_age'] ??
        mapArgs?['age'] ??
        peer['age'];

    final avatarUrl = (args?.recipientAvatarUrl.isNotEmpty == true
            ? args!.recipientAvatarUrl
            : (peer['avatar_url'] as String? ??
                peer['recipient_avatar_url'] as String? ??
                peer['partner_photo'] as String? ??
                peer['peer_photo'] as String? ??
                peer['avatar'] as String? ??
                ''))
        .trim();
    final imageProvider = resolveSanctuaryImageProvider(avatarUrl);
    final hasValidAvatar = imageProvider != null;

    final isVerified = args?.isVerified ??
        (peer['is_verified'] as bool? ??
            peer['is_kyc_verified'] as bool? ??
            peer['kyc_status'] as bool? ??
            false);

    final displayName = args != null
        ? '${args.recipientName}, ${args.recipientAge}'
        : (fallbackAge != null
            ? '$fallbackName, $fallbackAge'
            : '$fallbackName');
    final isOnline = args?.isOnline ?? (peer['is_online'] as bool? ?? true);
    final bridgeData = {
      ...dialogueState.bridgeData,
      if (args != null && args.hasWaKey) 'has_wa_key': true,
    };
    final promptText = args?.sharedContextQuote ?? dialogueState.sharedPrompt;

    ref.listen(chatDialogueControllerProvider(mId), (_, next) {
      final violation = next.violationAlert;
      if (violation != null && context.mounted) {
        showDialog<void>(
          context: context,
          builder: (_) => NlpWarningDialog(
            result: violation,
            isDark: isDark,
            onDismiss: () {
              Navigator.of(context).pop();
              notifier.dismissViolationAlert();
            },
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: isDark
            ? DarkSanctuaryTokens.surfaceCard
            : LightSanctuaryTokens.surfaceCard,
        elevation: 0.5,
        leading: BackButton(color: primaryText),
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            final detailArgs = SeekerProfileDetailArgs.fromPeer(
              peer: peer,
              args: args,
              matchId: mId,
            );
            Navigator.of(context).pushNamed(
              SeekerProfileDetailScreen.routeName,
              arguments: detailArgs,
            );
          },
          onLongPress: () => _showPeerProfileModal(
            context: context,
            isDark: isDark,
            displayName: displayName,
            avatarUrl: avatarUrl,
            hasValidAvatar: hasValidAvatar,
            isVerified: isVerified,
            isOnline: isOnline,
            peer: peer,
            args: args,
            matchId: mId,
            pine: pine,
            primaryText: primaryText,
            subText: subText,
          ),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: pine.withValues(alpha: 0.15),
                      backgroundImage: imageProvider,
                      child: !hasValidAvatar
                          ? Text(displayName.isNotEmpty ? displayName[0] : 'S',
                              style:
                                  TextStyle(color: pine, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isDark
                                ? DarkSanctuaryTokens.badgeOnline
                                : LightSanctuaryTokens.badgeOnline,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                  fontFamily: 'Serif',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified, size: 15, color: pine),
                          ],
                        ],
                      ),
                      Text(isOnline ? 'Quietly present' : 'Last seen recently',
                          style: TextStyle(fontSize: 11, color: subText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SacredBridgeAppBarAction(
            matchId: mId,
            isDark: isDark,
            bridgeData: bridgeData,
            wsService: ref.watch(chatWebSocketServiceProvider),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    DarkSanctuaryTokens.primaryCoral,
                    Color(0xFF4E9F76),
                  ],
                ),
              ),
              child:
                  const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            tooltip: 'Eva Dialogue Wingman',
            onPressed: () => _openWingmanCoach(
              context,
              isDark,
              args,
              peer,
              dialogueState,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: primaryText),
            color: isDark
                ? DarkSanctuaryTokens.surfaceCard
                : LightSanctuaryTokens.surfaceCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tooltip: 'Safety & Protection',
            onSelected: (val) {
              final rId = args?.recipientId ??
                  (peer['id'] as String? ??
                      peer['user_id'] as String? ??
                      'peer_seeker');
              final rName = args?.recipientName ??
                  (peer['full_name'] as String? ?? 'Seeker');
              if (val == 'info') {
                _showPeerProfileModal(
                  context: context,
                  isDark: isDark,
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                  hasValidAvatar: hasValidAvatar,
                  isVerified: isVerified,
                  isOnline: isOnline,
                  peer: peer,
                  args: args,
                  pine: pine,
                  primaryText: primaryText,
                  subText: subText,
                );
              } else if (val == 'report') {
                ChatSafetyDialog.showReportSheet(
                  context: context,
                  ref: ref,
                  recipientId: rId,
                  recipientName: rName,
                  isDark: isDark,
                  onUserBlocked: () {
                    if (context.mounted) Navigator.of(context).pop();
                  },
                );
              } else if (val == 'block') {
                ChatSafetyDialog.showBlockConfirmation(
                  context: context,
                  ref: ref,
                  recipientId: rId,
                  recipientName: rName,
                  isDark: isDark,
                  onUserBlocked: () {
                    if (context.mounted) Navigator.of(context).pop();
                  },
                );
              } else if (val == 'closure') {
                _showMindfulClosureModal(
                  context: context,
                  isDark: isDark,
                  notifier: notifier,
                  templates: dialogueState.closureTemplates,
                  recipientName: fallbackName.toString(),
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'info',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_pin_outlined,
                      size: 20,
                      color: pine,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Seeker Profile Info',
                      style: TextStyle(color: primaryText, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              if (!dialogueState.isClosed)
                PopupMenuItem<String>(
                  value: 'closure',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.spa_outlined,
                        size: 20,
                        color: Color(0xFF4E9F76),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Mindful Closure (Pass with Grace) 🍃',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF80E0A7) : const Color(0xFF2E7D32),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 20,
                      color: isDark
                          ? DarkSanctuaryTokens.primaryCoral
                          : LightSanctuaryTokens.terracottaAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Report Profile',
                      style: TextStyle(color: primaryText, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      Icons.block_rounded,
                      size: 20,
                      color: isDark
                          ? DarkSanctuaryTokens.primaryCoral
                          : LightSanctuaryTokens.terracottaAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Block User',
                      style: TextStyle(
                        color: isDark
                            ? DarkSanctuaryTokens.primaryCoral
                            : LightSanctuaryTokens.terracottaAccent,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                if (promptText.isNotEmpty)
                  SharedContextPromptCard(isDark: isDark, promptText: promptText),
                if (dialogueState.messages.isEmpty &&
                    dialogueState.icebreakers.isNotEmpty)
                  AiIcebreakerChipsRow(
                    isDark: isDark,
                    icebreakers: dialogueState.icebreakers,
                    onSelectIcebreaker: (prompt) => notifier.sendMessage(prompt),
                  ),
                Expanded(
                  child: dialogueState.messages.isEmpty
                      ? Center(
                          child: Text(
                            'Begin with intention. Conversations here flow unhurried.',
                            style: TextStyle(
                                fontSize: 13,
                                color: subText,
                                fontStyle: FontStyle.italic),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: dialogueState.messages.length,
                          itemBuilder: (context, index) {
                            final msg = dialogueState.messages[index];
                            return DialogueMessageBubble(
                              message: msg,
                              isMe: msg.isMe,
                              isDark: isDark,
                            );
                          },
                        ),
                ),
                if (dialogueState.bondingSparks.isNotEmpty && !dialogueState.sparksDismissed && !dialogueState.isClosed)
                  EvaBondingSparkBar(
                    isDark: isDark,
                    sparks: dialogueState.bondingSparks,
                    onSelectSpark: (spark) {
                      _chatInputController.text = spark;
                      _chatInputController.selection = TextSelection.fromPosition(
                        TextPosition(offset: spark.length),
                      );
                    },
                    onDismiss: () => notifier.dismissBondingSparks(),
                  ),
                if (dialogueState.isStagnant && !dialogueState.isClosed)
                  _buildMindfulStagnationBanner(
                    context: context,
                    isDark: isDark,
                    pine: pine,
                    primaryText: primaryText,
                    subText: subText,
                    onPassWithGrace: () => _showMindfulClosureModal(
                      context: context,
                      isDark: isDark,
                      notifier: notifier,
                      templates: dialogueState.closureTemplates,
                      recipientName: fallbackName.toString(),
                    ),
                  ),
                if (dialogueState.isClosed)
                  _buildClosedDialogueCard(
                    isDark: isDark,
                    subText: subText,
                    primaryText: primaryText,
                    closureNote: dialogueState.closureNote,
                  )
                else
                  TextOnlyChatInputBar(
                    isDark: isDark,
                    controller: _chatInputController,
                    onSendMessage: (cleanText) => notifier.sendMessage(cleanText),
                    onViolation: (violation) => notifier.setViolationAlert(violation),
                    onWingmanPressed: () => _openWingmanCoach(
                      context,
                      isDark,
                      args,
                      peer,
                      dialogueState,
                    ),
                  ),
              ],
            ),
          ),
          if (_isObscuredDueToFocusLoss && kIsWeb)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _isObscuredDueToFocusLoss = false;
                  });
                },
                child: Container(
                  color: const Color(0xF5090A10),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0x26FF2E7E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.lock_rounded, color: Color(0xFFFF2E7E), size: 30),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'SOVEREIGN PRIVACY SHIELD ACTIVE',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Dialogue masked while unfocused to prevent unauthorized screen capture. Tap anywhere to resume.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF8C93A8)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openWingmanCoach(
    BuildContext context,
    bool isDark,
    ChatDialogueArguments? args,
    Map<String, dynamic> peer,
    ChatDialogueState dialogueState,
  ) {
    final String rName = args?.recipientName ??
        (peer['full_name'] as String? ?? 'Seeker');
    final String lastMsg = dialogueState.messages.isNotEmpty
        ? dialogueState.messages.last.text
        : 'Start a thoughtful, slow dialogue.';
    final String pBio = (args != null && args.bio.isNotEmpty
            ? args.bio
            : (peer['bio'] as String? ?? ''))
        .trim();
    final List<String> pInterests = (args != null && args.interests.isNotEmpty
        ? args.interests
        : ((peer['interests'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[]));
    final List<Map<String, dynamic>> recentMsgs = dialogueState.messages
        .map((ChatMessage m) => <String, dynamic>{
              'sender': m.isMe ? 'me' : rName,
              'text': m.text,
              'isMe': m.isMe,
            })
        .toList();

    AiDialogueCoachSheet.show(
      context: context,
      partnerName: rName,
      lastIncomingMessage: lastMsg,
      isDark: isDark,
      partnerBio: pBio,
      partnerInterests: pInterests,
      recentMessages: recentMsgs,
      onApplyReply: (selectedReply) {
        _chatInputController.text = selectedReply;
        _chatInputController.selection = TextSelection.fromPosition(
          TextPosition(offset: selectedReply.length),
        );
      },
    );
  }

  void _showPeerProfileModal({
    required BuildContext context,
    required bool isDark,
    required String displayName,
    required String avatarUrl,
    required bool hasValidAvatar,
    required bool isVerified,
    required bool isOnline,
    required Map<String, dynamic> peer,
    required ChatDialogueArguments? args,
    String? matchId,
    required Color pine,
    required Color primaryText,
    required Color subText,
  }) {
    final bio = (args?.bio.isNotEmpty == true
            ? args!.bio
            : (peer['bio'] as String? ?? ''))
        .trim();
    final location = (args?.location.isNotEmpty == true
            ? args!.location
            : (peer['location'] as String? ??
                peer['city'] as String? ??
                'Ayodhya, Uttar Pradesh · GPS Verified'))
        .trim();
    final intentions = (peer['intentions'] as String? ??
            'Appreciating intentional conversations and authentic connection.')
        .trim();
    final interestsList = (args?.interests.isNotEmpty == true
        ? args!.interests
        : ((peer['interests'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[]));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cardBg = isDark
            ? DarkSanctuaryTokens.surfaceCard
            : LightSanctuaryTokens.surfaceCard;
        final cardBorder = isDark
            ? DarkSanctuaryTokens.surfaceCardBorder
            : LightSanctuaryTokens.surfaceCardBorder;

        void navigateToFullProfile() {
          Navigator.of(ctx).pop();
          final detailArgs = SeekerProfileDetailArgs.fromPeer(
            peer: peer,
            args: args,
            matchId: matchId,
          );
          Navigator.of(context).pushNamed(
            SeekerProfileDetailScreen.routeName,
            arguments: detailArgs,
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: subText.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  InkWell(
                    onTap: navigateToFullProfile,
                    borderRadius: BorderRadius.circular(50),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: pine.withValues(alpha: 0.15),
                          backgroundImage: resolveSanctuaryImageProvider(avatarUrl),
                          child: !hasValidAvatar
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0] : 'S',
                                  style: TextStyle(
                                    color: pine,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        if (isOnline)
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? DarkSanctuaryTokens.badgeOnline
                                  : LightSanctuaryTokens.badgeOnline,
                              shape: BoxShape.circle,
                              border: Border.all(color: cardBg, width: 2.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: navigateToFullProfile,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontFamily: 'Serif',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.verified, size: 20, color: pine),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? pine.withValues(alpha: 0.15)
                          : subText.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified
                              ? Icons.check_circle_outline
                              : Icons.shield_outlined,
                          size: 13,
                          color: isVerified ? pine : subText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified
                              ? 'Identity Verified Seeker'
                              : 'Sanctuary Seeker',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isVerified ? pine : subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: subText),
                      const SizedBox(width: 4),
                      Text(
                        location.isNotEmpty
                            ? location
                            : 'Ayodhya, Uttar Pradesh · GPS Verified',
                        style: TextStyle(fontSize: 12, color: subText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: cardBorder, height: 1),
                  const SizedBox(height: 14),
                  if (bio.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sacred Reflection',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: pine,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? DarkSanctuaryTokens.inputBackground
                            : LightSanctuaryTokens.chipBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        bio,
                        style: TextStyle(
                            fontSize: 13, color: primaryText, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Resonance Intentions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: pine,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DarkSanctuaryTokens.inputBackground
                          : LightSanctuaryTokens.chipBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      intentions,
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryText,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (interestsList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Core Passions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: pine,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: interestsList.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: pine.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: pine,
                                  fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryText,
                            side: BorderSide(color: cardBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Back to Chat',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pine,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: navigateToFullProfile,
                          icon: const Icon(Icons.person_pin_circle_outlined,
                              size: 18),
                          label: const Text('View Full Profile ✨',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMindfulStagnationBanner({
    required BuildContext context,
    required bool isDark,
    required Color pine,
    required Color primaryText,
    required Color subText,
    required VoidCallback onPassWithGrace,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A22) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A5946) : const Color(0xFFA5D6A7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.spa_rounded, size: 18, color: Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Eva AI Mindful Intercession',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Conversations have natural tides. If you wish to close this dialogue with grace, tap below.',
            style: TextStyle(fontSize: 12, color: subText, height: 1.35),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onPassWithGrace,
              style: TextButton.styleFrom(
                backgroundColor: pine.withValues(alpha: 0.15),
                foregroundColor: pine,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('Pass with Grace 🍃', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedDialogueCard({
    required bool isDark,
    required Color subText,
    required Color primaryText,
    String? closureNote,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🍃', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Dialogue Concluded with Grace',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          if (closureNote != null && closureNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '“${closureNote.trim()}”',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: primaryText,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'This conversation is peacefully archived in Past Reflections.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: subText),
          ),
        ],
      ),
    );
  }

  void _showMindfulClosureModal({
    required BuildContext context,
    required bool isDark,
    required ChatDialogueController notifier,
    required List<MindfulClosureTemplate> templates,
    required String recipientName,
  }) {
    final effectiveTemplates = templates.isNotEmpty
        ? templates
        : const [
            MindfulClosureTemplate(
              key: 'wavelength',
              title: 'Different Wavelengths',
              icon: '🌊',
              message:
                  'Thank you for sharing your time and thoughts with me. I feel our rhythms flow in different directions, so I wish you profound peace and the right connection on your journey.',
            ),
            MindfulClosureTemplate(
              key: 'self_focus',
              title: 'Focusing Inward',
              icon: '🌱',
              message:
                  'I have appreciated our exchange, but I need to step back and turn inward right now. May warmth and genuine resonance accompany your next chapter.',
            ),
            MindfulClosureTemplate(
              key: 'different_resonance',
              title: 'Different Resonance',
              icon: '✨',
              message:
                  'It was meaningful to cross paths here. I do not feel the spark evolving naturally, and out of deep respect for both our journeys, I bid you a gentle farewell.',
            ),
            MindfulClosureTemplate(
              key: 'silent_bow',
              title: 'Gentle Farewell',
              icon: '🍃',
              message:
                  'I bow gratefully to the quiet moment we shared and gently release our connection. Wishing you stillness, joy, and bright horizons ahead.',
            ),
          ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String selectedKey = effectiveTemplates.first.key;
        final noteController = TextEditingController(text: effectiveTemplates.first.message);
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cardBg = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
            final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
            final primaryText = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
            final subText = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
            final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: cardBorder, width: 1),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: subText.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text('🍃', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mindful Closure (Pass with Grace)',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Leaving a dialogue with clarity brings peace to both hearts. Choose a compassionate note or personalize below:',
                      style: TextStyle(fontSize: 12.5, color: subText, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    ...effectiveTemplates.map((tmpl) {
                      final isSelected = selectedKey == tmpl.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedKey = tmpl.key;
                              noteController.text = tmpl.message;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? pine.withValues(alpha: 0.12)
                                  : (isDark ? DarkSanctuaryTokens.inputBackground : LightSanctuaryTokens.chipBackground),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? pine : cardBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(tmpl.icon, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tmpl.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? pine : primaryText,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, size: 18, color: pine),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    Text(
                      'Farewell Note Preview & Personalization',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      style: TextStyle(fontSize: 13, color: primaryText),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? DarkSanctuaryTokens.inputBackground : LightSanctuaryTokens.inputBackground,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: pine, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: subText,
                              side: BorderSide(color: cardBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setModalState(() => isSubmitting = true);
                                    final success = await notifier.sendMindfulClosure(
                                      selectedKey,
                                      customNote: noteController.text,
                                    );
                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? 'Farewell sent with grace 🍃. Dialogue peacefully archived.'
                                                : 'Failed to complete closure. Please try again.',
                                          ),
                                          backgroundColor: success
                                              ? const Color(0xFF2E7D32)
                                              : (isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.terracottaAccent),
                                        ),
                                      );
                                    }
                                  },
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.spa_rounded, size: 16),
                            label: Text(
                              isSubmitting ? 'Concluding...' : 'Pass with Grace 🍃',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pine,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


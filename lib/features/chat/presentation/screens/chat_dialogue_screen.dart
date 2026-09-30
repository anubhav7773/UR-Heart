import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/flutter_windowmanager.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../data/chat_repository.dart';
import '../controllers/chat_dialogue_controller.dart';
import '../widgets/ai_icebreaker_chips_row.dart';
import '../widgets/chat_safety_dialog.dart';
import '../widgets/dialogue_message_bubble.dart';
import '../widgets/nlp_warning_dialog.dart';
import '../widgets/sacred_bridge_app_bar_action.dart';
import '../widgets/shared_context_prompt_card.dart';
import '../widgets/text_only_chat_input_bar.dart';
import '../../../ai_sanctuary/presentation/widgets/ai_dialogue_coach_sheet.dart';

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

class _ChatDialogueScreenState extends ConsumerState<ChatDialogueScreen> {
  final ScrollController _scrollController = ScrollController();

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
    try {
      FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
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
    try {
      FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (_) {}
    _scrollController.dispose();
    super.dispose();
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
    final hasValidAvatar = avatarUrl.isNotEmpty && avatarUrl.startsWith('http');

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
          onTap: () => _showPeerProfileModal(
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
                      backgroundImage:
                          hasValidAvatar ? NetworkImage(avatarUrl) : null,
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
            onPressed: () {
              final rName = args?.recipientName ??
                  (peer['full_name'] as String? ?? 'Seeker');
              final lastMsg = dialogueState.messages.isNotEmpty
                  ? dialogueState.messages.last.text
                  : 'Start a thoughtful, slow dialogue.';
              AiDialogueCoachSheet.show(
                context: context,
                partnerName: rName,
                lastIncomingMessage: lastMsg,
                isDark: isDark,
                onApplyReply: (_) {},
              );
            },
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
      body: SafeArea(
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
            TextOnlyChatInputBar(
              isDark: isDark,
              onSendMessage: (cleanText) => notifier.sendMessage(cleanText),
              onViolation: (violation) => notifier.setViolationAlert(violation),
            ),
          ],
        ),
      ),
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
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: pine.withValues(alpha: 0.15),
                        backgroundImage:
                            hasValidAvatar ? NetworkImage(avatarUrl) : null,
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pine,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Back to Dialogue',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

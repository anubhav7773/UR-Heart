import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/eva_controller.dart';

class EvaSanctuaryScreen extends ConsumerStatefulWidget {
  static const String routeName = '/ai-sanctuary';
  final bool animateOrb;

  const EvaSanctuaryScreen({super.key, this.animateOrb = true});

  @override
  ConsumerState<EvaSanctuaryScreen> createState() => _EvaSanctuaryScreenState();
}

class _EvaSanctuaryScreenState extends ConsumerState<EvaSanctuaryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _orbAnimController;

  final List<String> _quickPrompts = [
    'How should I reply to my match without sounding eager?',
    'Maine jo report file kiya tha, uska status kya hai?',
    'Main jisse baat kar raha hoon, unhe kya reply karoon?',
    'Mujhe is app me ek kami lag rahi hai (Feedback)',
    'UR-Heart ke unique features kya hain?',
    'Tumhe kisne banaya hai?',
  ];

  @override
  void initState() {
    super.initState();
    _orbAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.animateOrb) {
      _orbAnimController.repeat(reverse: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        ref.read(evaControllerProvider.notifier).setContext(
          screen: args['screen']?.toString() ?? 'Sanctuary',
          partnerName: args['partner_name']?.toString(),
          activePartner: args['active_partner'] is Map<String, dynamic>
              ? args['active_partner'] as Map<String, dynamic>
              : null,
          userTickets: args['user_tickets'] is List ? args['user_tickets'] as List : null,
        );
      }
    });
  }

  @override
  void dispose() {
    _orbAnimController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? presetText]) {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty) return;

    HapticFeedback.lightImpact();
    ref.read(evaControllerProvider.notifier).sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;
    final evaState = ref.watch(evaControllerProvider);

    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;

    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final accentEmerald = isDark
        ? const Color(0xFF4E9F76)
        : const Color(0xFF2E6B4F);

    final accentCoral = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: headlineColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            // Micro breathing avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentCoral, accentEmerald],
                ),
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eva Sanctuary',
                    style: TextStyle(
                      color: headlineColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Mindful AI by Asiverticals',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 10.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: mutedColor, size: 20),
            tooltip: 'Reset Conversation',
            onPressed: () {
              ref.read(evaControllerProvider.notifier).clearSession();
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Glowing breathing orb header (shown when conversation is fresh)
            if (evaState.messages.length <= 2)
              _buildGlowingSanctuaryOrb(accentEmerald, accentCoral, isDark),

            // Message dialogue list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: evaState.messages.length,
                itemBuilder: (context, index) {
                  final msg = evaState.messages[index];
                  final isUser = msg.role == 'user';
                  return _buildMessageBubble(
                    msg: msg,
                    isUser: isUser,
                    isDark: isDark,
                    cardBg: cardBg,
                    headlineColor: headlineColor,
                    mutedColor: mutedColor,
                    accentEmerald: accentEmerald,
                    accentCoral: accentCoral,
                  );
                },
              ),
            ),

            // Loading indicator
            if (evaState.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(accentCoral),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Eva is contemplating...',
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Quick suggestion pills
            if (!evaState.isLoading)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return ActionChip(
                      backgroundColor: isDark
                          ? const Color(0xFF1E2B23)
                          : const Color(0xFFEDE8E1),
                      side: BorderSide(
                        color: accentEmerald.withOpacity(0.3),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      label: Text(
                        _quickPrompts[i],
                        style: TextStyle(
                          fontSize: 11.5,
                          color: headlineColor,
                        ),
                      ),
                      onPressed: () => _handleSend(_quickPrompts[i]),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // Bottom Input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121815) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E2B23) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(color: headlineColor, fontSize: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: 'Ask Eva for mindful dating advice...',
                        hintStyle: TextStyle(color: mutedColor, fontSize: 13.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleSend(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [accentCoral, accentEmerald],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentCoral.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingSanctuaryOrb(
    Color accentEmerald,
    Color accentCoral,
    bool isDark,
  ) {
    return AnimatedBuilder(
      animation: _orbAnimController,
      builder: (context, child) {
        final scale = 0.95 + (0.08 * math.sin(_orbAnimController.value * math.pi));
        final glowRadius = 16.0 + (12.0 * _orbAnimController.value);

        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          child: Column(
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentCoral.withOpacity(0.9),
                        accentEmerald.withOpacity(0.6),
                        Colors.transparent,
                      ],
                      stops: const [0.2, 0.7, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentEmerald.withOpacity(isDark ? 0.35 : 0.2),
                        blurRadius: glowRadius,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.spa_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sacred Resonance Space',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8C9B90) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required dynamic msg,
    required bool isUser,
    required bool isDark,
    required Color cardBg,
    required Color headlineColor,
    required Color mutedColor,
    required Color accentEmerald,
    required Color accentCoral,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentCoral, accentEmerald],
                ),
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, size: 14, color: Colors.white),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark ? const Color(0xFF284435) : const Color(0xFFD1E7DD))
                    : cardBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? accentEmerald.withOpacity(0.4)
                      : (isDark
                          ? const Color(0xFF1E2B23)
                          : const Color(0xFFE2E8F0)),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: TextStyle(
                      color: headlineColor,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                  if (msg.isGuarded == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, size: 11, color: accentCoral),
                        const SizedBox(width: 4),
                        Text(
                          'Protected by Sanctuary Guardrails',
                          style: TextStyle(fontSize: 10, color: accentCoral),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

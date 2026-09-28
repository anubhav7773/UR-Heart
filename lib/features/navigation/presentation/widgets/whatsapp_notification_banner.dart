import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WhatsApp-style ultra-premium in-app heads-up floating notification banner.
/// 
/// Slides down smoothly from the top safe area, provides haptic feedback,
/// features WhatsApp-style sender avatar with status dot, bold typography,
/// "now" timestamp tag, swipe-up to dismiss, auto-dismiss, and direct tap-to-open.
class WhatsAppNotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final String type;
  final String? avatarUrl;
  final String? senderInitials;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration displayDuration;

  const WhatsAppNotificationBanner({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.avatarUrl,
    this.senderInitials,
    required this.isDark,
    required this.onTap,
    required this.onDismiss,
    this.displayDuration = const Duration(milliseconds: 4500),
  });

  @override
  State<WhatsAppNotificationBanner> createState() =>
      _WhatsAppNotificationBannerState();
}

class _WhatsAppNotificationBannerState extends State<WhatsAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 280),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    // Provide premium subtle haptic feedback when notification slides down
    HapticFeedback.lightImpact();

    _animController.forward();

    // Start auto-dismiss countdown
    _autoDismissTimer = Timer(widget.displayDuration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _autoDismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    // Theme color palettes
    final bgColor = isDark
        ? const Color(0xF216231C) // Deep emerald sanctuary
        : const Color(0xF8FFFFFF); // Clean crisp white

    final borderColor = isDark
        ? const Color(0x404E9F76) // Subtle luminous emerald border
        : const Color(0x1F000000);

    final titleColor = isDark ? Colors.white : const Color(0xFF111B21);
    final messageColor =
        isDark ? const Color(0xFFD1D7DB) : const Color(0xFF3B4A54);
    final timeColor =
        isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);

    // Accent color based on type
    final Color badgeColor;
    final IconData badgeIcon;
    if (widget.type.contains('message') || widget.type.contains('chat')) {
      badgeColor = const Color(0xFF25D366); // WhatsApp Green
      badgeIcon = Icons.chat_bubble_rounded;
    } else if (widget.type.contains('like') || widget.type.contains('resonate')) {
      badgeColor = const Color(0xFFE58B68); // Sanctuary Coral
      badgeIcon = Icons.favorite_rounded;
    } else if (widget.type.contains('match')) {
      badgeColor = const Color(0xFFD4AF37); // Luminous Gold
      badgeIcon = Icons.auto_awesome;
    } else {
      badgeColor = const Color(0xFF4E9F76); // Forest Pine
      badgeIcon = Icons.notifications_active_rounded;
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                top: 8.0,
              ),
              child: GestureDetector(
                onTap: () {
                  _autoDismissTimer?.cancel();
                  _dismiss();
                  widget.onTap();
                },
                onVerticalDragUpdate: (details) {
                  // Swipe up to dismiss immediately
                  if (details.primaryDelta! < -4) {
                    _dismiss();
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(22.0),
                          border: Border.all(color: borderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                              blurRadius: 22.0,
                              spreadRadius: 1.0,
                              offset: const Offset(0, 8.0),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // WhatsApp-style circular avatar with status dot
                                _buildAvatar(badgeColor, badgeIcon),
                                const SizedBox(width: 12.0),
                                // Content area
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Top row: App Name / Sender & "now" timestamp
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    widget.title,
                                                    style: TextStyle(
                                                      color: titleColor,
                                                      fontSize: 14.0,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: -0.2,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8.0),
                                          Text(
                                            'now',
                                            style: TextStyle(
                                              color: timeColor,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3.0),
                                      // Bottom row: Message preview
                                      Text(
                                        widget.message,
                                        style: TextStyle(
                                          color: messageColor,
                                          fontSize: 12.5,
                                          height: 1.28,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10.0),
                                // WhatsApp-style quick view chevron / action pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 6.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 13.0,
                                    color: badgeColor,
                                  ),
                                ),
                              ],
                            ),
                            // Tiny drag handle indicator at bottom
                            const SizedBox(height: 6.0),
                            Center(
                              child: Container(
                                width: 28.0,
                                height: 3.0,
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? Colors.white
                                          : Colors.black)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(2.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Color badgeColor, IconData badgeIcon) {
    final initials = widget.senderInitials ??
        (widget.title.isNotEmpty ? widget.title[0].toUpperCase() : 'U');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main circular avatar
        Container(
          width: 44.0,
          height: 44.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                badgeColor.withOpacity(0.85),
                badgeColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withOpacity(0.3),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    widget.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        // WhatsApp green online dot / badge indicator
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: 14.0,
            height: 14.0,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isDark
                    ? const Color(0xFF16231C)
                    : const Color(0xFFFFFFFF),
                width: 2.0,
              ),
            ),
            child: Center(
              child: Icon(
                badgeIcon,
                size: 7.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

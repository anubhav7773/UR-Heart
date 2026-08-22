import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../chat_screen.dart';

class ActiveMatchesTray extends StatelessWidget {
  final List<Conversation> matches;
  final void Function(Conversation) onMatchTap;

  const ActiveMatchesTray({
    super.key,
    required this.matches,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          final firstName = match.partnerName.split(' ').first;
          final bool isHighlighted = match.unreadCount > 0 || !match.hasMessages;

          return GestureDetector(
            onTap: () => onMatchTap(match),
            child: Container(
              width: 68,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 60dp Circular Avatar with Unread/Presence Indicators
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        padding: const EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHighlighted
                                ? AppTheme.accent_primary
                                : AppTheme.border_subtle,
                            width: 2.0,
                          ),
                          boxShadow: isHighlighted
                              ? [
                                  BoxShadow(
                                    color: AppTheme.accent_primary.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipOval(
                          child: match.partnerAvatar.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: match.partnerAvatar,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 120,
                                  memCacheHeight: 120,
                                  placeholder: (_, __) => Container(
                                    color: AppTheme.surface_interactive,
                                    child: const Icon(
                                      Icons.person,
                                      color: AppTheme.text_tertiary,
                                      size: 28,
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppTheme.surface_interactive,
                                    child: const Icon(
                                      Icons.person,
                                      color: AppTheme.text_tertiary,
                                      size: 28,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppTheme.surface_interactive,
                                  child: const Icon(
                                    Icons.person,
                                    color: AppTheme.text_tertiary,
                                    size: 28,
                                  ),
                                ),
                        ),
                      ),

                      // Online Presence Indicator
                      if (match.isOnline)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.status_online,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.surface_root,
                                width: 2.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Name Label
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.text_primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

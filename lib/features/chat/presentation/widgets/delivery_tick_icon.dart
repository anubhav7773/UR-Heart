import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/chat_models.dart';

/// WhatsApp-style delivery tick visual indicator:
/// - Single grey tick: Persisted on backend (status = 'sent')
/// - Double grey tick: Received by recipient socket (status = 'delivered')
/// - Double blue tick: Viewed in active viewport (status = 'read')
class DeliveryTickIcon extends StatelessWidget {
  final MessageDeliveryStatus status;
  final bool isDark;
  final double size;

  const DeliveryTickIcon({
    super.key,
    required this.status,
    required this.isDark,
    this.size = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    final greyColor = isDark
        ? DarkSanctuaryTokens.tickGrey
        : LightSanctuaryTokens.tickGrey;
    final blueColor = isDark
        ? DarkSanctuaryTokens.tickBlue
        : LightSanctuaryTokens.tickBlue;

    switch (status) {
      case MessageDeliveryStatus.sent:
        return Icon(
          Icons.check,
          size: size,
          color: greyColor,
        );
      case MessageDeliveryStatus.delivered:
        return Icon(
          Icons.done_all,
          size: size,
          color: greyColor,
        );
      case MessageDeliveryStatus.read:
        return Icon(
          Icons.done_all,
          size: size,
          color: blueColor,
        );
    }
  }
}

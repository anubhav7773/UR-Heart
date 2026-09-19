import 'package:flutter/material.dart';
import 'package:ur_heart/core/widgets/luxury_empty_card.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        title: const Text('Direct Chats'),
        backgroundColor: const Color(0xFF0A0A0D),
        elevation: 0,
      ),
      body: LuxuryEmptyCard(
        icon: Icons.chat_bubble_rounded,
        accentColor: const Color(0xFF08D9D6),
        title: "Direct Encrypted Chats",
        description: "Mutual matches and unlocked Second-Chance DMs will appear in this private ledger.",
        actionLabel: "Check Missed Connections",
        onAction: () => Navigator.of(context).pushNamed('/matches'),
      ),
    );
  }
}

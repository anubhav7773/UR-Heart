import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ai_sanctuary_repository.dart';

class EvaState {
  final List<EvaMessage> messages;
  final bool isLoading;
  final String? activePartnerName;
  final String activeScreen;

  const EvaState({
    required this.messages,
    this.isLoading = false,
    this.activePartnerName,
    this.activeScreen = 'Sanctuary',
  });

  EvaState copyWith({
    List<EvaMessage>? messages,
    bool? isLoading,
    String? activePartnerName,
    String? activeScreen,
  }) {
    return EvaState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      activePartnerName: activePartnerName ?? this.activePartnerName,
      activeScreen: activeScreen ?? this.activeScreen,
    );
  }
}

final evaControllerProvider =
    StateNotifierProvider<EvaController, EvaState>((ref) {
  final repository = ref.watch(aiSanctuaryRepositoryProvider);
  return EvaController(repository);
});

class EvaController extends StateNotifier<EvaState> {
  final AiSanctuaryRepository _repository;

  EvaController(this._repository)
      : super(EvaState(
          messages: [
            EvaMessage(
              role: 'assistant',
              content:
                  'Namaste. Main Eva hoon — Asiverticals dwara banayi gayi aapki mindful AI companion. '
                  'Aap mujhse apne matches ke messages par advice, date preparation, ya profile clarity ke baare me pooch sakte hain.',
              timestamp: DateTime.now(),
            ),
          ],
        ));

  void setContext({required String screen, String? partnerName}) {
    state = state.copyWith(activeScreen: screen, activePartnerName: partnerName);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final userMsg = EvaMessage(
      role: 'user',
      content: trimmed,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    // Format history
    final history = state.messages.map((m) => {
          'role': m.role,
          'content': m.content,
        }).toList();

    final result = await _repository.chatWithEva(
      message: trimmed,
      history: history,
      context: {
        'screen': state.activeScreen,
        if (state.activePartnerName != null)
          'partner_name': state.activePartnerName,
      },
    );

    final replyText = result['reply']?.toString() ??
        'Main aapke connection ko samajh rahi hoon. Kripya thoda aur vistaar se batayein.';
    final isGuarded = result['is_guarded'] == true;

    final assistantMsg = EvaMessage(
      role: 'assistant',
      content: replyText,
      isGuarded: isGuarded,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, assistantMsg],
      isLoading: false,
    );
  }

  void clearSession() {
    state = EvaState(
      messages: [
        EvaMessage(
          role: 'assistant',
          content:
              'Namaste. Main Eva hoon — Asiverticals dwara banayi gayi aapki mindful AI companion. '
              'Aap mujhse apne matches ke messages par advice, date preparation, ya profile clarity ke baare me pooch sakte hain.',
          timestamp: DateTime.now(),
        ),
      ],
      activePartnerName: state.activePartnerName,
      activeScreen: state.activeScreen,
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/blind_date_repository.dart';
import '../../domain/blind_date_models.dart';

enum BlindDateQueueStatus { idle, waiting, matched, error }

class BlindDateState {
  final BlindDateQueueStatus queueStatus;
  final BlindDateSessionModel? session;
  final List<BlindDateMessageModel> messages;
  final bool isLoading;
  final String? errorMessage;
  final int remainingSeconds;

  const BlindDateState({
    this.queueStatus = BlindDateQueueStatus.idle,
    this.session,
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.remainingSeconds = 300,
  });

  BlindDateState copyWith({
    BlindDateQueueStatus? queueStatus,
    BlindDateSessionModel? session,
    List<BlindDateMessageModel>? messages,
    bool? isLoading,
    String? errorMessage,
    int? remainingSeconds,
  }) {
    return BlindDateState(
      queueStatus: queueStatus ?? this.queueStatus,
      session: session ?? this.session,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

final blindDateControllerProvider =
    StateNotifierProvider<BlindDateController, BlindDateState>((ref) {
  final repository = ref.watch(blindDateRepositoryProvider);
  return BlindDateController(repository);
});

class BlindDateController extends StateNotifier<BlindDateState> {
  final BlindDateRepository _repository;
  Timer? _queuePollTimer;
  Timer? _countdownTimer;
  Timer? _messagesPollTimer;

  BlindDateController(this._repository) : super(const BlindDateState());

  @override
  void dispose() {
    _stopAllTimers();
    super.dispose();
  }

  void _stopAllTimers() {
    _queuePollTimer?.cancel();
    _queuePollTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _messagesPollTimer?.cancel();
    _messagesPollTimer = null;
  }

  Future<void> joinQueue() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _repository.joinQueue();
      final status = res['status'] as String? ?? 'waiting';

      if (status == 'matched') {
        final sessionJson = res['session'] as Map<String, dynamic>? ?? {};
        final session = BlindDateSessionModel.fromJson(sessionJson);
        state = state.copyWith(
          isLoading: false,
          queueStatus: BlindDateQueueStatus.matched,
          session: session,
          remainingSeconds: session.remainingSeconds,
        );
        _startSessionLifecycle(session.id);
      } else {
        state = state.copyWith(
          isLoading: false,
          queueStatus: BlindDateQueueStatus.waiting,
        );
        _startQueuePolling();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        queueStatus: BlindDateQueueStatus.error,
        errorMessage: 'Unable to enter Sanctuary queue. Please try again.',
      );
    }
  }

  void _startQueuePolling() {
    _queuePollTimer?.cancel();
    _queuePollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final res = await _repository.checkQueueStatus();
        final status = res['status'] as String? ?? 'idle';

        if (status == 'matched') {
          timer.cancel();
          final sessionJson = res['session'] as Map<String, dynamic>? ?? {};
          final session = BlindDateSessionModel.fromJson(sessionJson);
          state = state.copyWith(
            queueStatus: BlindDateQueueStatus.matched,
            session: session,
            remainingSeconds: session.remainingSeconds,
          );
          _startSessionLifecycle(session.id);
        } else if (status == 'idle') {
          timer.cancel();
          state = state.copyWith(queueStatus: BlindDateQueueStatus.idle);
        }
      } catch (e) {
        debugPrint('[BLIND DATE POLL ERROR] $e');
      }
    });
  }

  void _startSessionLifecycle(String sessionId) {
    _queuePollTimer?.cancel();

    // Start 1-second countdown ticker
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        timer.cancel();
        // Session expired
        if (state.session != null && state.session!.status == 'active') {
          state = state.copyWith(
            session: state.session!.copyWith(status: 'expired'),
          );
        }
      }
    });

    // Start messages polling every 2.5 seconds
    fetchMessages(sessionId);
    _messagesPollTimer?.cancel();
    _messagesPollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      fetchMessages(sessionId);
    });
  }

  Future<void> fetchMessages(String sessionId) async {
    try {
      final msgs = await _repository.getMessages(sessionId);
      state = state.copyWith(messages: msgs);
    } catch (e) {
      debugPrint('[MESSAGES FETCH ERROR] $e');
    }
  }

  Future<void> sendMessage(String text) async {
    final sessionId = state.session?.id;
    if (sessionId == null || text.trim().isEmpty) return;

    try {
      final msg = await _repository.sendMessage(sessionId, text.trim());
      state = state.copyWith(
        messages: [...state.messages, msg],
      );
    } catch (e) {
      debugPrint('[SEND MESSAGE ERROR] $e');
    }
  }

  Future<void> resonate() async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final updated = await _repository.submitDecision(sessionId, 'resonate');
      state = state.copyWith(
        isLoading: false,
        session: state.session?.copyWith(
          status: updated.status,
          myDecision: 'resonate',
          matchId: updated.matchId,
          partner: updated.partner ?? state.session?.partner,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to submit resonance.',
      );
    }
  }

  Future<void> pass() async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final updated = await _repository.submitDecision(sessionId, 'pass');
      _stopAllTimers();
      state = state.copyWith(
        isLoading: false,
        session: state.session?.copyWith(
          status: updated.status,
          myDecision: 'pass',
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to submit pass.',
      );
    }
  }

  Future<void> cancelQueue() async {
    _stopAllTimers();
    try {
      await _repository.cancelQueue();
    } catch (e) {
      debugPrint('[CANCEL QUEUE ERROR] $e');
    }
    state = const BlindDateState();
  }

  void resetSession() {
    _stopAllTimers();
    state = const BlindDateState();
  }
}

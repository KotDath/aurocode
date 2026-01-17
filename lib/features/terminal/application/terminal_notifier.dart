import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/terminal_state.dart';
import '../infrastructure/process_terminal_repository.dart';

class TerminalNotifier extends StateNotifier<TerminalState> {
  final TerminalRepository _repository;
  StreamSubscription<String>? _outputSubscription;

  TerminalNotifier(this._repository) : super(const TerminalState());

  Future<void> startSession({String shell = 'bash'}) async {
    try {
      final session = await _repository.startSession(shell);

      state = state.copyWith(
        session: session,
        isConnected: true,
      );

      _outputSubscription = _repository.getOutput(session.id).listen((output) {
        if (!mounted) return;
        final updatedSession = state.session?.addOutput(output);
        state = state.copyWith(session: updatedSession);
      });
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to start terminal: $e',
        isConnected: false,
      );
    }
  }

  Future<void> writeInput(String input) async {
    if (state.session == null) return;

    await _repository.writeInput(state.session!.id, input);
    state = state.copyWith(currentInput: '');
  }

  void updateInput(String input) {
    state = state.copyWith(currentInput: input);
  }

  Future<void> clear() async {
    if (state.session == null) return;

    final clearedSession = state.session!.copyWith(output: []);
    state = state.copyWith(session: clearedSession);
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    if (state.session != null) {
      _repository.closeSession(state.session!.id);
    }
    super.dispose();
  }
}

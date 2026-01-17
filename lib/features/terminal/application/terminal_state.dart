import '../domain/entities/terminal_session.dart';

class TerminalState {
  final TerminalSession? session;
  final String currentInput;
  final bool isConnected;
  final String? error;

  const TerminalState({
    this.session,
    this.currentInput = '',
    this.isConnected = false,
    this.error,
  });

  TerminalState copyWith({
    TerminalSession? session,
    String? currentInput,
    bool? isConnected,
    String? error,
  }) {
    return TerminalState(
      session: session ?? this.session,
      currentInput: currentInput ?? this.currentInput,
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }

  String get outputText {
    return session?.output.map((l) => l.text).join('') ?? '';
  }
}

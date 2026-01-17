import '../domain/entities/run_config.dart';

class RunnerState {
  final RunSession? session;
  final bool isRunning;
  final String? error;

  const RunnerState({
    this.session,
    this.isRunning = false,
    this.error,
  });

  RunnerState copyWith({
    RunSession? session,
    bool? isRunning,
    String? error,
  }) {
    return RunnerState(
      session: session ?? this.session,
      isRunning: isRunning ?? this.isRunning,
      error: error,
    );
  }
}

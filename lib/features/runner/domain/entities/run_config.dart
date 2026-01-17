class RunConfig {
  final String projectPath;
  final String target;
  final List<String> args;

  const RunConfig({
    required this.projectPath,
    this.target = 'linux',
    this.args = const [],
  });
}

enum RunStatus {
  idle,
  starting,
  running,
  stopping,
  finished,
  error,
}

class RunSession {
  final String id;
  final RunConfig config;
  final RunStatus status;
  final String output;
  final int? exitCode;

  const RunSession({
    required this.id,
    required this.config,
    this.status = RunStatus.idle,
    this.output = '',
    this.exitCode,
  });

  RunSession copyWith({
    String? id,
    RunConfig? config,
    RunStatus? status,
    String? output,
    int? exitCode,
  }) {
    return RunSession(
      id: id ?? this.id,
      config: config ?? this.config,
      status: status ?? this.status,
      output: output ?? this.output,
      exitCode: exitCode ?? this.exitCode,
    );
  }

  RunSession appendOutput(String text) {
    return copyWith(output: output + text);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/runner_state.dart';
import '../domain/entities/run_config.dart';

class RunnerNotifier extends StateNotifier<RunnerState> {
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  RunnerNotifier() : super(const RunnerState());

  Future<void> run(String projectPath, {String target = 'linux'}) async {
    if (state.isRunning) return;

    final config = RunConfig(projectPath: projectPath, target: target);
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    state = state.copyWith(
      session: RunSession(
        id: sessionId,
        config: config,
        status: RunStatus.starting,
      ),
      isRunning: true,
    );

    try {
      _process = await Process.start(
        'flutter',
        ['run', '-d', target],
        workingDirectory: projectPath,
        environment: Platform.environment,
      );

      state = state.copyWith(
        session: state.session?.copyWith(status: RunStatus.running),
      );

      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .listen((data) {
        if (!mounted) return;
        state = state.copyWith(
          session: state.session?.appendOutput(data),
        );
      });

      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .listen((data) {
        if (!mounted) return;
        state = state.copyWith(
          session: state.session?.appendOutput('[stderr] $data'),
        );
      });

      final exitCode = await _process!.exitCode;
      if (!mounted) return;

      state = state.copyWith(
        session: state.session?.copyWith(
          status: RunStatus.finished,
          exitCode: exitCode,
        ),
        isRunning: false,
      );
    } catch (e) {
      state = state.copyWith(
        session: state.session?.copyWith(status: RunStatus.error),
        isRunning: false,
        error: e.toString(),
      );
    }
  }

  Future<void> stop() async {
    if (!state.isRunning || _process == null) return;

    state = state.copyWith(
      session: state.session?.copyWith(status: RunStatus.stopping),
    );

    _process!.kill();
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();

    state = state.copyWith(
      session: state.session?.copyWith(status: RunStatus.finished),
      isRunning: false,
    );
  }

  @override
  void dispose() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _process?.kill();
    super.dispose();
  }
}

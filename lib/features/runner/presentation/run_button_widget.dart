import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/runner_notifier.dart';
import '../application/runner_state.dart';
import '../domain/entities/run_config.dart';

// Provider
final runnerProvider =
    StateNotifierProvider<RunnerNotifier, RunnerState>((ref) {
  return RunnerNotifier();
});

class RunButtonWidget extends ConsumerWidget {
  final String projectPath;

  const RunButtonWidget({
    super.key,
    required this.projectPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runnerProvider);

    return SizedBox(
      height: 24,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 11),
        ),
        onPressed: state.isRunning
            ? () => ref.read(runnerProvider.notifier).stop()
            : () => ref.read(runnerProvider.notifier).run(projectPath),
        icon: state.isRunning
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                state.session?.status == RunStatus.running
                    ? Icons.stop
                    : Icons.play_arrow,
                size: 14,
              ),
        label: Text(state.isRunning ? 'Stop' : 'Run'),
      ),
    );
  }
}

class RunOutputPanel extends ConsumerWidget {
  const RunOutputPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runnerProvider);

    if (state.session == null) {
      return const Center(
        child: Text(
          'No run session',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          state.session!.output,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/terminal_notifier.dart';
import '../application/terminal_state.dart';
import '../infrastructure/process_terminal_repository.dart';

// Providers
final terminalRepositoryProvider = Provider<TerminalRepository>((ref) {
  return ProcessTerminalRepository();
});

final terminalProvider =
    StateNotifierProvider<TerminalNotifier, TerminalState>((ref) {
  final repository = ref.watch(terminalRepositoryProvider);
  return TerminalNotifier(repository);
});

class TerminalWidget extends ConsumerStatefulWidget {
  const TerminalWidget({super.key});

  @override
  ConsumerState<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends ConsumerState<TerminalWidget> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(terminalProvider.notifier).startSession();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terminalProvider);

    ref.listen<TerminalState>(terminalProvider, (previous, next) {
      if (previous?.session?.output.length !=
          next.session?.output.length) {
        _scrollToBottom();
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context, state),
          Expanded(child: _buildTerminalContent(context, state)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TerminalState state) {
    return Container(
      height: 36,
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.terminal,
            size: 14,
            color: state.isConnected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          const Text('Terminal', style: TextStyle(fontSize: 13)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.clear_all, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Clear',
            onPressed: () {
              ref.read(terminalProvider.notifier).clear();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTerminalContent(BuildContext context, TerminalState state) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(
                  state.outputText,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          _buildInputLine(context, state),
        ],
      ),
    );
  }

  Widget _buildInputLine(BuildContext context, TerminalState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '\$ ',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              color: Colors.green.shade400,
            ),
          ),
          Expanded(
            child: KeyboardListener(
              focusNode: _focusNode,
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  final input = _controller.text;
                  if (input.isNotEmpty) {
                    ref.read(terminalProvider.notifier).writeInput(input);
                    _controller.clear();
                  }
                }
              },
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    ref.read(terminalProvider.notifier).writeInput(value);
                    _controller.clear();
                    _focusNode.requestFocus();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

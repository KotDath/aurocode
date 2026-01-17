import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

class NativeTerminalWidget extends StatefulWidget {
  const NativeTerminalWidget({super.key});

  @override
  State<NativeTerminalWidget> createState() => _NativeTerminalWidgetState();
}

class _NativeTerminalWidgetState extends State<NativeTerminalWidget> {
  late final Terminal _terminal;
  Pty? _pty;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _startPty();
  }

  Future<void> _startPty() async {
    try {
      final shell = Platform.environment['SHELL'] ?? 'bash';

      _pty = Pty.start(
        shell,
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
        workingDirectory: Directory.current.path,
        environment: Platform.environment,
      );

      _pty!.output.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      _pty!.exitCode.then((code) {
        _terminal.write('\n[Process exited with code $code]\n');
        setState(() => _isConnected = false);
      });

      _terminal.onOutput = (data) {
        _pty!.write(const Utf8Encoder().convert(data));
      };

      _terminal.onResize = (w, h, pw, ph) {
        _pty!.resize(h, w);
      };

      setState(() => _isConnected = true);
    } catch (e) {
      _terminal.write('Failed to start terminal: $e\n');
    }
  }

  @override
  void dispose() {
    _pty?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          _buildHeader(context),
          Expanded(child: _buildTerminalView()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 36,
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.terminal,
            size: 14,
            color: _isConnected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          const Text('Terminal', style: TextStyle(fontSize: 13)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Restart',
            onPressed: () {
              _pty?.kill();
              _terminal.buffer.clear();
              _startPty();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTerminalView() {
    return TerminalView(
      _terminal,
      textStyle: const TerminalStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 13,
      ),
      padding: const EdgeInsets.all(8),
      autofocus: true,
    );
  }
}

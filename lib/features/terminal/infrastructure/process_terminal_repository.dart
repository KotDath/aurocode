import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/entities/terminal_session.dart';

abstract class TerminalRepository {
  Future<TerminalSession> startSession(String shell);
  Future<void> writeInput(String sessionId, String input);
  Stream<String> getOutput(String sessionId);
  Future<void> closeSession(String sessionId);
}

class ProcessTerminalRepository implements TerminalRepository {
  final _sessions = <String, Process>{};
  final _outputControllers = <String, StreamController<String>>{};

  @override
  Future<TerminalSession> startSession(String shell) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    final process = await Process.start(
      shell,
      [],
      environment: Platform.environment,
      workingDirectory: Directory.current.path,
    );

    _sessions[sessionId] = process;
    _outputControllers[sessionId] = StreamController<String>.broadcast();

    process.stdout.listen((data) {
      _outputControllers[sessionId]?.add(utf8.decode(data));
    });

    process.stderr.listen((data) {
      _outputControllers[sessionId]?.add(utf8.decode(data));
    });

    process.exitCode.then((code) {
      _outputControllers[sessionId]?.add('\n[Process exited with code $code]\n');
      _outputControllers[sessionId]?.close();
      _sessions.remove(sessionId);
    });

    return TerminalSession(
      id: sessionId,
      shell: shell,
      isActive: true,
    );
  }

  @override
  Future<void> writeInput(String sessionId, String input) async {
    final process = _sessions[sessionId];
    if (process == null) return;

    process.stdin.add(utf8.encode('$input\n'));
    await process.stdin.flush();
  }

  @override
  Stream<String> getOutput(String sessionId) {
    return _outputControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Future<void> closeSession(String sessionId) async {
    final process = _sessions[sessionId];
    if (process != null) {
      process.kill();
      await _outputControllers[sessionId]?.close();
      _sessions.remove(sessionId);
      _outputControllers.remove(sessionId);
    }
  }
}

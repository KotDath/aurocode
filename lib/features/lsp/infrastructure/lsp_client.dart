/// LSP Client implementation.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../editor/domain/entities/diagnostic.dart';
import '../../editor/domain/entities/highlight_token.dart';
import '../domain/entities/lsp_messages.dart';
import 'json_rpc_codec.dart';
import 'language_server_config.dart';

/// State of the LSP client.
enum LspClientState { disconnected, initializing, ready, shuttingDown, stopped }

/// Diagnostics for a specific file URI.
class FileDiagnostics {
  final String uri;
  final List<EditorDiagnostic> diagnostics;

  const FileDiagnostics({required this.uri, required this.diagnostics});
}

/// A client for communicating with a language server.
class LspClient {
  final LanguageServerConfig config;
  final String? workspaceRoot;

  Process? _process;
  StreamSubscription<LspMessage>? _messageSubscription;

  int _nextRequestId = 1;
  final Map<int, Completer<LspResponse>> _pendingRequests = {};

  LspClientState _state = LspClientState.disconnected;
  LspClientState get state => _state;

  Map<String, dynamic>? serverCapabilities;
  List<String>? semanticTokenTypes;
  List<String>? semanticTokenModifiers;

  final _notificationController = StreamController<LspNotification>.broadcast();
  Stream<LspNotification> get notifications => _notificationController.stream;

  final _diagnosticsController = StreamController<FileDiagnostics>.broadcast();
  /// Stream of diagnostics updates per file.
  Stream<FileDiagnostics> get diagnostics => _diagnosticsController.stream;

  LspClient({required this.config, this.workspaceRoot});

  Future<void> start() async {
    if (_state != LspClientState.disconnected) {
      throw StateError('Client is already started');
    }

    _process = await Process.start(
      config.executable,
      config.arguments,
      environment: config.environment,
      workingDirectory: workspaceRoot,
    );

    final messageStream = _process!.stdout.transform(const LspMessageDecoder());

    _messageSubscription = messageStream.listen(
      _handleMessage,
      onError: (error) => stderr.writeln('[LSP ${config.id}] Error: $error'),
      onDone: () {
        _state = LspClientState.stopped;
        _cancelAllPending();
      },
    );

    _process!.stderr.transform(utf8.decoder).listen((data) {
      stderr.writeln('[LSP ${config.id}] stderr: $data');
    });

    _state = LspClientState.initializing;
    await _initialize();
  }

  Future<void> _initialize() async {
    final response = await sendRequest('initialize', {
      'processId': pid,
      'rootUri': workspaceRoot != null ? Uri.file(workspaceRoot!).toString() : null,
      'capabilities': _clientCapabilities(),
      'clientInfo': {'name': 'Aurocode', 'version': '0.1.0'},
    });

    if (response.isError) {
      throw Exception('Initialize failed: ${response.error}');
    }

    final result = response.result as Map<String, dynamic>;
    serverCapabilities = result['capabilities'] as Map<String, dynamic>?;
    _extractSemanticTokensLegend();

    sendNotification('initialized', {});
    _state = LspClientState.ready;
    stdout.writeln('[LSP ${config.id}] Initialized');
  }

  void _extractSemanticTokensLegend() {
    final provider = serverCapabilities?['semanticTokensProvider'] as Map<String, dynamic>?;
    final legend = provider?['legend'] as Map<String, dynamic>?;
    if (legend == null) return;

    semanticTokenTypes = (legend['tokenTypes'] as List?)?.cast<String>() ?? [];
    semanticTokenModifiers = (legend['tokenModifiers'] as List?)?.cast<String>() ?? [];
  }

  Map<String, dynamic> _clientCapabilities() {
    return {
      'textDocument': {
        'synchronization': {'didSave': true},
        'semanticTokens': {
          'requests': {'full': true},
          'tokenTypes': [
            'namespace', 'type', 'class', 'enum', 'interface', 'struct',
            'typeParameter', 'parameter', 'variable', 'property', 'enumMember',
            'function', 'method', 'macro', 'keyword', 'modifier', 'comment',
            'string', 'number', 'regexp', 'operator',
          ],
          'tokenModifiers': [
            'declaration', 'definition', 'readonly', 'static', 'deprecated',
            'abstract', 'async', 'documentation', 'defaultLibrary',
          ],
          'formats': ['relative'],
        },
      },
    };
  }

  void _handleMessage(LspMessage message) {
    switch (message) {
      case LspResponse():
        _pendingRequests.remove(message.id)?.complete(message);
      case LspNotification():
        _handleNotification(message);
      case LspRequest():
        _handleServerRequest(message);
    }
  }

  void _handleNotification(LspNotification notification) {
    _notificationController.add(notification);

    if (notification.method == 'textDocument/publishDiagnostics') {
      _handlePublishDiagnostics(notification.params as Map<String, dynamic>);
    }
  }

  void _handlePublishDiagnostics(Map<String, dynamic> params) {
    final uri = params['uri'] as String;
    final rawDiagnostics = params['diagnostics'] as List<dynamic>? ?? [];

    final diagnostics = rawDiagnostics.map((d) {
      final diag = d as Map<String, dynamic>;
      final range = diag['range'] as Map<String, dynamic>;
      final start = range['start'] as Map<String, dynamic>;
      final end = range['end'] as Map<String, dynamic>;

      // LSP gives line/character, we need to store them temporarily.
      // We'll convert to offsets in the service layer where we have the source text.
      final startLine = start['line'] as int;
      final startChar = start['character'] as int;
      final endLine = end['line'] as int;
      final endChar = end['character'] as int;

      final severity = switch (diag['severity'] as int?) {
        1 => DiagnosticSeverity.error,
        2 => DiagnosticSeverity.warning,
        3 => DiagnosticSeverity.information,
        4 => DiagnosticSeverity.hint,
        _ => DiagnosticSeverity.error,
      };

      return EditorDiagnostic(
        // Store line-based info temporarily encoded as start/end
        // The service will need to convert these to offsets
        start: _encodeLineChar(startLine, startChar),
        end: _encodeLineChar(endLine, endChar),
        message: diag['message'] as String? ?? '',
        severity: severity,
        code: diag['code']?.toString(),
        source: diag['source'] as String?,
      );
    }).toList();

    _diagnosticsController.add(FileDiagnostics(uri: uri, diagnostics: diagnostics));
  }

  /// Encode line and character into a single int for temporary storage.
  /// Format: line * 100000 + character (supports up to 100k columns per line).
  int _encodeLineChar(int line, int character) => line * 100000 + character;

  /// Decode line and character from encoded int.
  static (int line, int character) decodeLineChar(int encoded) =>
      (encoded ~/ 100000, encoded % 100000);

  void _handleServerRequest(LspRequest request) {
    switch (request.method) {
      case 'client/registerCapability':
      case 'workspace/configuration':
        _sendResponse(request.id, []);
      default:
        _sendErrorResponse(request.id, LspErrorCodes.methodNotFound, 'Not found');
    }
  }

  void _sendResponse(int id, dynamic result) {
    _send(LspResponse(id: id, result: result));
  }

  void _sendErrorResponse(int id, int code, String message) {
    _send(LspResponse(id: id, error: LspError(code: code, message: message)));
  }

  Future<LspResponse> sendRequest(String method, [dynamic params]) {
    final id = _nextRequestId++;
    final request = LspRequest(id: id, method: method, params: params);

    final completer = Completer<LspResponse>();
    _pendingRequests[id] = completer;
    _send(request);

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(id);
        return LspResponse(id: id, error: const LspError(code: -32603, message: 'Timeout'));
      },
    );
  }

  void sendNotification(String method, [dynamic params]) {
    _send(LspNotification(method: method, params: params));
  }

  void _send(LspMessage message) {
    _process?.stdin.add(encodeLspMessage(message));
  }

  void _cancelAllPending() {
    for (final c in _pendingRequests.values) {
      c.completeError(StateError('Client stopped'));
    }
    _pendingRequests.clear();
  }

  void didOpen({required String uri, required String languageId, required int version, required String text}) {
    sendNotification('textDocument/didOpen', {
      'textDocument': {'uri': uri, 'languageId': languageId, 'version': version, 'text': text},
    });
  }

  void didChange({
    required String uri, 
    required int version, 
    required String text,
    Map<String, dynamic>? range,
    int? rangeLength,
  }) {
    final change = <String, dynamic>{'text': text};
    if (range != null) {
      change['range'] = range;
    }
    if (rangeLength != null) {
      change['rangeLength'] = rangeLength;
    }

    sendNotification('textDocument/didChange', {
      'textDocument': {'uri': uri, 'version': version},
      'contentChanges': [change],
    });
  }

  void didClose({required String uri}) {
    sendNotification('textDocument/didClose', {'textDocument': {'uri': uri}});
  }

  Future<List<HighlightToken>?> getSemanticTokens(String uri, String sourceText) async {
    if (semanticTokenTypes == null || semanticTokenTypes!.isEmpty) return null;

    final response = await sendRequest('textDocument/semanticTokens/full', {
      'textDocument': {'uri': uri},
    });

    if (response.isError || response.result == null) return null;

    final data = ((response.result as Map<String, dynamic>)['data'] as List?)?.cast<int>();
    if (data == null || data.isEmpty) return null;

    return _decodeSemanticTokens(data, sourceText);
  }

  List<HighlightToken> _decodeSemanticTokens(List<int> data, String sourceText) {
    final tokens = <HighlightToken>[];
    
    // DEBUG: Trace semantic tokens
    print('[LSP] Decoding ${data.length} integers from semantic tokens response');
    
    // Calculate line start offsets by scanning for newlines
    final lineOffsets = <int>[0];
    for (var i = 0; i < sourceText.length; i++) {
      if (sourceText.codeUnitAt(i) == 10) { // \n
        lineOffsets.add(i + 1);
      }
    }
    // Ensure we can handle "next line" even if file doesn't end in newline
    // by treating subsequent lines as starting at EOF
    
    var line = 0;
    var character = 0;

    for (var i = 0; i < data.length; i += 5) {
      final deltaLine = data[i];
      final deltaStart = data[i + 1];
      final length = data[i + 2];
      final tokenTypeIndex = data[i + 3];
      final tokenModifierBitset = data[i + 4];

      // Update position using LSP delta encoding
      if (deltaLine > 0) {
        line += deltaLine;
        character = deltaStart;
      } else {
        character += deltaStart;
      }

      // Calculate byte offset from line/character
      int offset = 0;
      if (line < lineOffsets.length) {
        offset = lineOffsets[line] + character;
      } else {
        // Line out of bounds (shouldn't happen with correct LSP server)
        // Fallback: estimate based on last line
        offset = sourceText.length; 
      }
      
      // Clamp to source length
      if (offset > sourceText.length) offset = sourceText.length;
      var end = offset + length;
      if (end > sourceText.length) end = sourceText.length;

      final typeName = (semanticTokenTypes != null && tokenTypeIndex < semanticTokenTypes!.length)
          ? semanticTokenTypes![tokenTypeIndex]
          : 'unknown';

      tokens.add(HighlightToken(
        start: offset,
        end: end,
        type: typeName,
        modifiers: _decodeModifiers(tokenModifierBitset),
      ));
    }
    return tokens;
  }

  List<String> _decodeModifiers(int bitfield) {
    if (semanticTokenModifiers == null) return [];
    final mods = <String>[];
    for (var i = 0; i < semanticTokenModifiers!.length; i++) {
      if ((bitfield & (1 << i)) != 0) mods.add(semanticTokenModifiers![i]);
    }
    return mods;
  }

  Future<void> shutdown() async {
    if (_state == LspClientState.disconnected || _state == LspClientState.stopped) return;
    _state = LspClientState.shuttingDown;
    try {
      await sendRequest('shutdown');
      sendNotification('exit');
    } catch (_) {}
    await _cleanup();
  }

  Future<void> _cleanup() async {
    await _messageSubscription?.cancel();
    await _notificationController.close();
    await _diagnosticsController.close();
    _process = null;
    _state = LspClientState.stopped;
  }
}

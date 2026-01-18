/// High-level LSP service for managing language server clients.
library;

import 'dart:async';

import 'package:path/path.dart' as p;

import '../../editor/domain/entities/highlight_token.dart';
import '../infrastructure/language_server_config.dart';
import '../infrastructure/lsp_client.dart';

/// Service for managing LSP clients.
class LspService {
  final String? workspaceRoot;

  final Map<String, LspClient> _clients = {};
  final Map<String, int> _documentVersions = {};
  final Map<String, StreamSubscription<FileDiagnostics>> _diagnosticsSubs = {};
  
  final _diagnosticsController = StreamController<FileDiagnostics>.broadcast();
  /// Stream of diagnostics updates from all clients.
  Stream<FileDiagnostics> get diagnostics => _diagnosticsController.stream;

  LspService({this.workspaceRoot});

  Future<LspClient?> getClientForFile(String filePath) async {
    final extension = p.extension(filePath);
    if (extension.isEmpty) return null;

    final config = LanguageServers.forExtension(extension);
    if (config == null) return null;

    return getOrCreateClient(config);
  }

  Future<LspClient> getOrCreateClient(LanguageServerConfig config) async {
    var client = _clients[config.id];

    if (client == null || client.state == LspClientState.stopped) {
      client = LspClient(config: config, workspaceRoot: workspaceRoot);
      _clients[config.id] = client;

      try {
        await client.start();
        // Subscribe to diagnostics from this client
        _diagnosticsSubs[config.id]?.cancel();
        _diagnosticsSubs[config.id] = client.diagnostics.listen((diag) {
          _diagnosticsController.add(diag);
        });
      } catch (e) {
        _clients.remove(config.id);
        rethrow;
      }
    }

    return client;
  }

  Future<void> documentOpened({required String filePath, required String content}) async {
    final client = await getClientForFile(filePath);
    if (client == null || client.state != LspClientState.ready) return;

    final uri = Uri.file(filePath).toString();
    final languageId = _getLanguageId(filePath);
    final version = _bumpVersion(uri);

    client.didOpen(uri: uri, languageId: languageId, version: version, text: content);
  }

  Future<void> documentChanged({
    required String filePath, 
    required String content,
    Map<String, dynamic>? range,
    int? rangeLength,
  }) async {
    final client = await getClientForFile(filePath);
    if (client == null || client.state != LspClientState.ready) return;

    final uri = Uri.file(filePath).toString();
    final version = _bumpVersion(uri);

    client.didChange(
      uri: uri, 
      version: version, 
      text: content,
      range: range,
      rangeLength: rangeLength,
    );
  }

  Future<void> documentClosed({required String filePath}) async {
    final client = await getClientForFile(filePath);
    if (client == null || client.state != LspClientState.ready) return;

    final uri = Uri.file(filePath).toString();
    _documentVersions.remove(uri);
    client.didClose(uri: uri);
  }

  Future<List<HighlightToken>?> getSemanticTokens(String filePath, String sourceText) async {
    final client = await getClientForFile(filePath);
    if (client == null || client.state != LspClientState.ready) return null;

    return client.getSemanticTokens(Uri.file(filePath).toString(), sourceText);
  }

  int _bumpVersion(String uri) {
    final version = (_documentVersions[uri] ?? 0) + 1;
    _documentVersions[uri] = version;
    return version;
  }

  String _getLanguageId(String filePath) {
    final ext = p.extension(filePath).replaceFirst('.', '');
    return switch (ext) {
      'dart' => 'dart',
      'rs' => 'rust',
      'go' => 'go',
      'c' || 'h' => 'c',
      'cpp' || 'cc' || 'cxx' || 'hpp' => 'cpp',
      'ts' => 'typescript',
      'tsx' => 'typescriptreact',
      'js' => 'javascript',
      'jsx' => 'javascriptreact',
      'py' => 'python',
      _ => ext,
    };
  }

  Future<void> dispose() async {
    for (final sub in _diagnosticsSubs.values) {
      await sub.cancel();
    }
    _diagnosticsSubs.clear();
    await _diagnosticsController.close();
    final futures = _clients.values.map((c) => c.shutdown());
    await Future.wait(futures);
    _clients.clear();
    _documentVersions.clear();
  }
}

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

  Future<void> documentChanged({required String filePath, required String content}) async {
    final client = await getClientForFile(filePath);
    if (client == null || client.state != LspClientState.ready) return;

    final uri = Uri.file(filePath).toString();
    final version = _bumpVersion(uri);

    client.didChange(uri: uri, version: version, text: content);
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
    final futures = _clients.values.map((c) => c.shutdown());
    await Future.wait(futures);
    _clients.clear();
    _documentVersions.clear();
  }
}

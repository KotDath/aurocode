/// LSP-based highlight provider using semantic tokens.
library;

import 'dart:async';

import '../domain/entities/highlight_token.dart';
import '../domain/highlight_provider.dart';
import '../../lsp/application/lsp_service.dart';

/// A highlight provider that uses LSP semantic tokens.
class LspHighlightProvider implements HighlightProvider {
  final LspService _lspService;

  LspHighlightProvider(this._lspService);

  @override
  Future<List<HighlightToken>?> highlight(
    String code,
    String language, [
    String? filePath,
  ]) async {
    if (filePath == null || code.isEmpty) return null;

    try {
      return await _lspService.getSemanticTokens(filePath, code);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> documentOpened(
    String filePath,
    String content,
    String language,
  ) async {
    try {
      await _lspService.documentOpened(filePath: filePath, content: content);
    } catch (_) {
      // Ignore errors - LSP might not be available
    }
  }

  @override
  Future<void> documentChanged(String filePath, String content) async {
    try {
      await _lspService.documentChanged(filePath: filePath, content: content);
    } catch (_) {
      // Ignore errors
    }
  }

  @override
  Future<void> documentClosed(String filePath) async {
    try {
      await _lspService.documentClosed(filePath: filePath);
    } catch (_) {
      // Ignore errors
    }
  }

  @override
  void dispose() {
    // LspService is managed externally
  }
}

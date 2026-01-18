/// LSP-based highlight provider using semantic tokens.
library;

import 'dart:async';

import '../domain/entities/highlight_token.dart';
import '../domain/entities/rope.dart';
import '../domain/entities/rope_change.dart';
import '../domain/highlight_provider.dart';
import '../../lsp/application/lsp_service.dart';

/// A highlight provider that uses LSP semantic tokens.
class LspHighlightProvider implements HighlightProvider {
  final LspService _lspService;

  LspHighlightProvider(this._lspService);

  @override
  bool get prefersWindowedUpdates => false;

  @override
  Future<List<HighlightToken>?> highlight(
    Rope content,
    String language, {
    String? filePath,
    int? visibleStart,
    int? visibleEnd,
  }) async {
    if (filePath == null) return null; // LSP needs a file path

    // Optimization: Don't send content if we don't have to.
    // However, LspService.getSemanticTokens currently takes 'sourceText'.
    // We should probably check if the doc is already open and synchronized.
    // For now, if we are editing, we are sending didChange events.
    // So we can pass empty string or partial string if the service supports it?
    // Actually, LspClient.getSemanticTokens typically needs to know the context for a fresh request,
    // but standard LSP creates a request 'textDocument/semanticTokens/full' or 'range'.
    // If we want range, we should implement getSemanticTokensRange.
    
    // For now, let's just pass the full text as string if we HAVE to, 
    // BUT strictly speaking, if we rely on DID_CHANGE, we shouldn't need to re-send text here?
    // The current LspService.getSemanticTokens implementation calls `client.getSemanticTokens(...)`.
    // Let's check LspClient.
    
    // For safety with current implementation, we might still convert to string, 
    // BUT we should really be using range requests if possible for large files.
    // OR we trust that `didChange` has kept the server up to date.
    
    // Let's blindly toString() for now BUT logic shows we should optimize `LspService` next.
    // Wait, the plan said "Update to use Rope".
    
    try {
      // If we have a visible range, we could try to ask for range tokens if supported.
      // But `LspService` doesn't expose range tokens yet.
      // Let's pass the Rope.toString() for now to satisfy the compiler, 
      // but mark TODO to optimize LspService.
      // actually, let's just use empty string if we assume sync is handled by didChange?
      // No, `LspClient.getSemanticTokens` might use the provided text to overlay? 
      // Let's look at `LspClient` in a future step.
      
      return await _lspService.getSemanticTokens(filePath, content.toString()); 
    } catch (e) {
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
  Future<void> documentChangedWithRange(String filePath, Rope rope, RopeChange change) async {
    try {
      // Calculate LSP Range from change.start and change.deletedText
      final startOffset = change.start;
      final (startLine, startCol) = rope.lineColAt(startOffset);
      
      int endLine = startLine;
      int endCol = startCol;
      
      if (change.deletedText != null && change.deletedText!.isNotEmpty) {
        // We need to advance endLine/endCol by the deleted text (which fits in the 'hole' started at start)
        final deleted = change.deletedText!;
        for (var i = 0; i < deleted.length; i++) {
          if (deleted[i] == '\n') {
            endLine++;
            endCol = 0;
          } else {
            endCol++;
          }
        }
      }
      
      final range = {
        'start': {'line': startLine, 'character': startCol},
        'end': {'line': endLine, 'character': endCol},
      };

      await _lspService.documentChanged(
        filePath: filePath, 
        content: change.text,
        range: range,
        rangeLength: change.deletedText?.length,
      );
    } catch (e) {
      // Fallback to full sync if something fails
      print('Incremental sync failed: $e, falling back to full sync');
      await documentChanged(filePath, rope.toString());
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

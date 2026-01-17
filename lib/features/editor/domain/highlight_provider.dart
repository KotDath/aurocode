/// Abstract interface for highlight providers.
///
/// Implementations:
/// - RegexHighlightProvider (sync, from re_highlight)
/// - LspHighlightProvider (async, semantic tokens)
/// - TreeSitterHighlightProvider (future, AST-based)
library;

import 'entities/highlight_token.dart';

/// Contract for highlight providers.
abstract class HighlightProvider {
  /// Highlight the given code and return a list of tokens.
  ///
  /// [code] - The source code to highlight.
  /// [language] - The language identifier (e.g., 'dart', 'rust').
  /// [filePath] - Optional file path for LSP (needed for document sync).
  ///
  /// Returns null if highlighting is not available for this language.
  Future<List<HighlightToken>?> highlight(
    String code,
    String language, [
    String? filePath,
  ]);

  /// Notify the provider that a document was opened.
  Future<void> documentOpened(String filePath, String content, String language) async {}

  /// Notify the provider that a document was changed.
  Future<void> documentChanged(String filePath, String content) async {}

  /// Notify the provider that a document was closed.
  Future<void> documentClosed(String filePath) async {}

  /// Release resources.
  void dispose();
}

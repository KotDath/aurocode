/// Regex-based highlight provider using re_highlight.
///
/// This wraps the existing SyntaxHighlighterService to conform to the
/// HighlightProvider interface.
library;

import '../domain/entities/highlight_token.dart';
import '../domain/highlight_provider.dart';
import 'syntax_highlighter.dart';

/// A highlight provider that uses regex patterns.
class RegexHighlightProvider implements HighlightProvider {
  // ignore: unused_field - kept for future use when we convert TextSpan to tokens
  final SyntaxHighlighterService _service;

  RegexHighlightProvider([SyntaxHighlighterService? service])
      : _service = service ?? SyntaxHighlighterService();

  @override
  Future<List<HighlightToken>?> highlight(
    String code,
    String language, [
    String? filePath,
  ]) async {
    // The regex highlighter returns a TextSpan directly.
    // For now, we return null and let the CodeController fallback to
    // using the SyntaxHighlighterService directly for TextSpan building.
    // In the future, we could convert TextSpan to HighlightToken list.
    return null;
  }

  @override
  Future<void> documentOpened(
      String filePath, String content, String language) async {
    // Regex doesn't need document lifecycle events
  }

  @override
  Future<void> documentChanged(String filePath, String content) async {
    // Regex doesn't need document lifecycle events
  }

  @override
  Future<void> documentClosed(String filePath) async {
    // Regex doesn't need document lifecycle events
  }

  @override
  void dispose() {
    // No resources to dispose
  }
}

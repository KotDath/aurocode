/// Regex-based highlight provider using re_highlight.
///
/// This wraps the existing SyntaxHighlighterService to conform to the
/// HighlightProvider interface.
library;

import '../domain/entities/highlight_token.dart';
import '../domain/entities/rope.dart';
import '../domain/entities/rope_change.dart';
import '../domain/highlight_provider.dart';
import 'syntax_highlighter.dart';

/// A highlight provider that uses regex patterns.
class RegexHighlightProvider implements HighlightProvider {
  // ignore: unused_field - kept for future use when we convert TextSpan to tokens
  final SyntaxHighlighterService _service;

  RegexHighlightProvider([SyntaxHighlighterService? service])
      : _service = service ?? SyntaxHighlighterService();

  @override
  bool get prefersWindowedUpdates => true;

  @override
  Future<List<HighlightToken>?> highlight(
    Rope content,
    String language, {
    String? filePath,
    int? visibleStart,
    int? visibleEnd,
  }) async {
    // Optimization: If visible range is provided, only highlight that chunk.
    // We add a buffer of lines before/after to handle context slightly better,
    // though regex is stateless per call usually.
    
    String codeToHighlight;
    int offset = 0;
    
    if (content.isEmpty) return [];

    if (visibleStart != null && visibleEnd != null) {
      // Add buffer (e.g. 50 lines) to ensure context for regexes that might look behind slightly?
      // Actually strictly speaking, simple regex highlighting might fail on boundaries.
      // But for "big.txt" perf, this is necessary.
      
      final maxLineIndex = content.lineCount - 1;
      
      // Expand range to line boundaries
      final startLineIndex = content.lineIndexAt(visibleStart);
      // Go back 100 lines for context
      final safeStartLine = (startLineIndex - 100).clamp(0, maxLineIndex);
      final safeStart = content.lineStartOffset(safeStartLine);
      
      final endLineIndex = content.lineIndexAt(visibleEnd);
      // Go forward 100 lines
      final safeEndLine = (endLineIndex + 100).clamp(0, maxLineIndex);
      // Get end of that line
      // safeEndLine is valid index. lineEndOffset needs valid index.
      // lineEndOffset returns offset inclusive of newline potentially.
      final safeEnd = content.lineEndOffset(safeEndLine);
      
      codeToHighlight = content.substring(safeStart, safeEnd);
      offset = safeStart;
    } else {
      codeToHighlight = content.toString();
    }
    
    final tokens = await _service.highlightAsTokens(codeToHighlight, language);
    
    // Shift tokens by offset
    if (offset > 0 && tokens != null) {
      for (final token in tokens) {
        token.start += offset;
        token.end += offset;
      }
    }
    
    return tokens;
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
  Future<void> documentChangedWithRange(String filePath, Rope rope, RopeChange change) async {
    // Regex doesn't support incremental yet, fallback to full if logic was implemented
    // But since it's stateless, we do nothing or wait for highlight() call.
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

/// Abstract interface for highlight providers.
///
/// Implementations:
/// - RegexHighlightProvider (sync, from re_highlight)
/// - LspHighlightProvider (async, semantic tokens)
/// - TreeSitterHighlightProvider (future, AST-based)
library;

import 'entities/highlight_token.dart';
import 'entities/rope.dart';
import 'entities/rope_change.dart';

/// Contract for highlight providers.
abstract class HighlightProvider {
  /// Whether this provider prefers to receive updates based on the visible window.
  /// 
  /// If true, the editor will effectively "stream" highlighting requests as the user scrolls.
  /// If false, the editor will typically request highlighting only when content changes.
  bool get prefersWindowedUpdates => false;

  /// Highlight the given code and return a list of tokens.
  ///
  /// [code] - The source code to highlight.
  /// [language] - The language identifier (e.g., 'dart', 'rust').
  /// [filePath] - Optional file path for LSP (needed for document sync).
  ///
  /// Returns null if highlighting is not available for this language.
  Future<List<HighlightToken>?> highlight(
    Rope content,
    String language, {
    String? filePath,
    int? visibleStart,
    int? visibleEnd,
  });

  /// Notify the provider that a document was opened.
  Future<void> documentOpened(String filePath, String content, String language) async {}

  /// Notify the provider that a document was changed.
  Future<void> documentChanged(String filePath, String content) async {}

  /// Notify the provider that a document was changed incrementally.
  /// Actually, `start` is stable unless we deleted things before it? No, `start` is the insertion point.
  /// The position `start` in the old document is the same "location" as `start` in the new document IF we view it as an insertion point.
  /// EXCEPT if we replaced a range.
  /// 
  /// If we replaced `[start, end)` with `text`:
  /// The insertion point is `start`.
  /// The range in the *old* document was `[start, end)`.
  /// We need to calculate line/col of `start` and `end` in the *old* document?
  /// Or can we calculate `start` in new document (it's the same offset) and derive `end` from `change.end - change.start` (length)?
  /// 
  /// In the OLD document, `start` maps to (line, col).
  /// In the NEW document, `start` maps to (line, col) (same place, usually, unless we deleted newlines before it? No, it's absolute offset).
  /// 
  /// Wait. `Rope.lineColAt(offset)` is O(log N).
  /// The offset `start` represents the same "point" in the stream relative to the beginning.
  /// So `rope.lineColAt(start)` on the *new* rope is fine for the start position?
  /// NO. If I replaced "A\nB" with "C", the `start` is 0.
  /// Old: 0->(0,0), End (2) -> (1,1).
  /// New: 0->(0,0).
  /// 
  /// But if I use the *new* rope, I can't calculate where the *old* `end` was (line/col wise) easily if I don't have the old rope.
  /// 
  /// Suggestion: Pass `Rope oldRope` to the callback? `RopeEditorController` has `_rope` (new). It doesn't keep old rope around unless we modify it.
  /// 
  /// Alternative: Just accept that for now we might be slightly off or expensive?
  /// Or: Update `RopeEditorController` to provide `oldRope`?
  /// Or: `RopeChange` should include the *deleted text*?
  /// If `RopeChange` includes `deletedText` (the text that was in [start, end)), then we can calculate line/col of `end` by adding line count of deleted text to `start` line/col?
  /// 
  /// Let's update `RopeChange` to include `deletedText`?
  /// Or just `RopeEditorController` calls `onChanged` *before* applying the change?
  /// No, `onChanged` usually implies "did change".
  /// 
  /// Let's assume for `LspHighlightProvider` we can just send full update if we can't figure it out?
  /// 
  /// WAIT. `CodeEditorWidget` receives `(rope, change)`. `rope` is NEW.
  /// We need `oldRope` to calculate the range of the deleted text correctly?
  /// 
  /// Actually, we can use `rope` (new) to find `start` (line, col).
  /// For `end`, IF it was a pure insertion (`start == end`), then `end` (line, col) == `start` (line, col).
  /// IF it was a deletion (`text` is empty), `start` and `end` are in the OLD coordinates.
  /// In the new rope, `start` corresponds to the point where text was removed.
  /// But we don't know "how many lines were removed" just from `start` and `end` integers, unless we check the content... that is gone.
  /// 
  /// **CRITICAL**: We need `oldRope` or `deletedText` to correctly calculate the LSP Range for a replacement/deletion.
  /// 
  /// Let's verify `RopeEditorController`. I can modify `insert`/`delete`/`replace` to capture `deletedText` before modifying.
  /// 
  /// Re-checking `RopeChange`.
  /// 
  Future<void> documentChangedWithRange(String filePath, Rope rope, RopeChange change) async {}

  /// Notify the provider that a document was closed.
  Future<void> documentClosed(String filePath) async {}

  /// Release resources.
  void dispose();
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/entities/rope.dart';
import '../domain/entities/rope_change.dart';



class RopeEditorController extends ChangeNotifier implements TextInputClient {
  Rope _rope;
  TextSelection _selection;
  TextInputConnection? _textInputConnection;
  
  // Undo/redo stacks
  final List<_HistoryEntry> _undoStack = [];
  final List<_HistoryEntry> _redoStack = [];
  static const int _maxHistorySize = 1000;
  static const Duration _coalesceTimeout = Duration(milliseconds: 500);
  
  // Track if we're in the middle of undo/redo to avoid recording
  bool _isUndoingOrRedoing = false;
  
  /// Whether the editor is read-only.
  final bool readOnly;
  
  /// Callback when content changes.
  final void Function(Rope rope, RopeChange? change)? onChanged;

  RopeEditorController({
    String initialText = '',
    this.readOnly = false,
    this.onChanged,
  })  : _rope = Rope(initialText),
        _selection = const TextSelection.collapsed(offset: 0);

  /// Creates a controller from an existing rope.
  RopeEditorController.fromRope({
    required Rope rope,
    this.readOnly = false,
    this.onChanged,
  })  : _rope = rope,
        _selection = const TextSelection.collapsed(offset: 0);
  Rope get rope => _rope;
  
  /// The current text as string.
  String get text => _rope.toString();
  
  /// The current selection/cursor position.
  TextSelection get selection => _selection;
  
  /// Total character count.
  int get length => _rope.length;
  
  /// Total line count.
  int get lineCount => _rope.lineCount;
  
  /// Whether there is a selection (not just cursor).
  bool get hasSelection => _selection.baseOffset != _selection.extentOffset;
  
  /// The cursor offset (extent of selection).
  int get cursorOffset => _selection.extentOffset;
  
  /// Whether undo is available.
  bool get canUndo => _undoStack.isNotEmpty;
  
  /// Whether redo is available.
  bool get canRedo => _redoStack.isNotEmpty;
  
  // Search state
  List<(int, int)> _searchMatches = [];
  int _currentMatchIndex = -1;
  String _searchQuery = '';
  bool _searchCaseSensitive = false;
  
  /// Current search matches.
  List<(int, int)> get searchMatches => _searchMatches;
  
  /// Current search match index.
  int get currentMatchIndex => _currentMatchIndex;
  
  /// Current search query.
  String get searchQuery => _searchQuery;
  
  /// Whether there are search results.
  bool get hasSearchResults => _searchMatches.isNotEmpty;
  
  // ============================================================
  // History Management
  // ============================================================
  
  /// Records current state to undo stack.
  /// Uses coalescing: rapid edits are grouped together.
  void _recordHistory({bool forceNew = false}) {
    if (_isUndoingOrRedoing) return;
    
    final now = DateTime.now();
    
    // Coalesce with previous entry if within timeout and not forced
    if (!forceNew && _undoStack.isNotEmpty) {
      final last = _undoStack.last;
      if (now.difference(last.timestamp) < _coalesceTimeout) {
        // Don't create new entry, just update the target for undo
        return;
      }
    }
    
    // Clear redo stack on new edit
    _redoStack.clear();
    
    // Add to undo stack
    _undoStack.add(_HistoryEntry(_rope, _selection));
    
    // Limit stack size
    while (_undoStack.length > _maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }
  
  /// Undoes the last edit operation.
  void undo() {
    if (!canUndo) return;
    
    _isUndoingOrRedoing = true;
    
    // Save current state to redo
    _redoStack.add(_HistoryEntry(_rope, _selection));
    
    // Restore previous state
    final entry = _undoStack.removeLast();
    _rope = entry.rope;
    _selection = TextSelection(
      baseOffset: entry.selection.baseOffset.clamp(0, _rope.length),
      extentOffset: entry.selection.extentOffset.clamp(0, _rope.length),
    );
    
    _isUndoingOrRedoing = false;
    
    _updateTextInputState();
    onChanged?.call(_rope, null);
    notifyListeners();
  }
  
  /// Redoes the last undone operation.
  void redo() {
    if (!canRedo) return;
    
    _isUndoingOrRedoing = true;
    
    // Save current state to undo
    _undoStack.add(_HistoryEntry(_rope, _selection));
    
    // Restore redo state
    final entry = _redoStack.removeLast();
    _rope = entry.rope;
    _selection = TextSelection(
      baseOffset: entry.selection.baseOffset.clamp(0, _rope.length),
      extentOffset: entry.selection.extentOffset.clamp(0, _rope.length),
    );
    
    _isUndoingOrRedoing = false;
    
    _updateTextInputState();
    onChanged?.call(_rope, null);
    notifyListeners();
  }
  
  /// Clears all history.
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  // ============================================================
  // Search
  // ============================================================
  
  /// Searches for [query] in the rope.
  /// 
  /// Populates [searchMatches] and jumps to first match.
  void search(String query, {bool caseSensitive = false}) {
    _searchQuery = query;
    _searchCaseSensitive = caseSensitive;
    
    if (query.isEmpty) {
      _searchMatches = [];
      _currentMatchIndex = -1;
      notifyListeners();
      return;
    }
    
    _searchMatches = _rope.findAll(query, caseSensitive: caseSensitive);
    
    if (_searchMatches.isEmpty) {
      _currentMatchIndex = -1;
    } else {
      // Find first match at or after cursor
      final cursorPos = _selection.baseOffset;
      _currentMatchIndex = 0;
      for (var i = 0; i < _searchMatches.length; i++) {
        if (_searchMatches[i].$1 >= cursorPos) {
          _currentMatchIndex = i;
          break;
        }
      }
      _jumpToCurrentMatch();
    }
    
    notifyListeners();
  }
  
  /// Jumps to the next search match.
  void findNext() {
    if (_searchMatches.isEmpty) return;
    
    _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    _jumpToCurrentMatch();
    notifyListeners();
  }
  
  /// Jumps to the previous search match.
  void findPrev() {
    if (_searchMatches.isEmpty) return;
    
    _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
    _jumpToCurrentMatch();
    notifyListeners();
  }
  
  /// Clears the current search.
  void clearSearch() {
    _searchQuery = '';
    _searchMatches = [];
    _currentMatchIndex = -1;
    notifyListeners();
  }
  
  void _jumpToCurrentMatch() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _searchMatches.length) return;
    
    final (start, end) = _searchMatches[_currentMatchIndex];
    _selection = TextSelection(baseOffset: start, extentOffset: end);
    _updateTextInputState();
  }

  // ============================================================
  // Text Manipulation
  // ============================================================

  /// Sets the rope content, optionally preserving cursor.
  void setRope(Rope newRope, {bool preserveCursor = false}) {
    _rope = newRope;
    if (!preserveCursor) {
      _selection = TextSelection.collapsed(offset: newRope.length.clamp(0, newRope.length));
    } else {
      // Clamp selection to valid range
      _selection = TextSelection(
        baseOffset: _selection.baseOffset.clamp(0, newRope.length),
        extentOffset: _selection.extentOffset.clamp(0, newRope.length),
      );
    }
    _updateTextInputState();
    onChanged?.call(_rope, null);
    notifyListeners();
  }

  /// Inserts text at the current cursor position.
  void insertText(String text) {
    if (readOnly || text.isEmpty) return;
    
    final sw = Stopwatch()..start();
    
    _recordHistory();
    
    final offset = _selection.baseOffset;
    _rope = _rope.insert(offset, text);
    _selection = TextSelection.collapsed(offset: offset + text.length);
    
    _updateTextInputState();
    notifyListeners();
    onChanged?.call(_rope, RopeChange(
        start: offset, 
        end: offset, 
        text: text,
        deletedText: '',
    ));
    sw.stop();
    print('Insert "${text.replaceAll('\n', '\\n')}" took ${sw.elapsedMicroseconds}µs');
  }

  /// Deletes the current selection.
  void deleteSelection() {
    if (readOnly || !hasSelection) return;
    
    final sw = Stopwatch()..start();
    _recordHistory(forceNew: true);
    
    final start = _selection.start;
    final end = _selection.end;
    final deleted = _rope.substring(start, end);
    
    _rope = _rope.delete(start, end);
    _selection = TextSelection.collapsed(offset: start);
    
    _updateTextInputState();
    onChanged?.call(_rope, RopeChange(
        start: start, 
        end: end, 
        text: '', 
        deletedText: deleted
    ));
    notifyListeners();
    sw.stop();
    print('Delete selection took ${sw.elapsedMicroseconds}µs');
  }

  /// Deletes one character before cursor (backspace).
  void deleteBackward() {
    if (readOnly) return;
    
    final sw = Stopwatch()..start();
    
    if (hasSelection) {
      deleteSelection();
      sw.stop();
      return;
    }
    
    if (_selection.baseOffset > 0) {
      _recordHistory();
      
      final offset = _selection.baseOffset;
      final deleted = _rope.substring(offset - 1, offset);
      _rope = _rope.delete(offset - 1, offset);
      _selection = TextSelection.collapsed(offset: offset - 1);
      
      notifyListeners();
      onChanged?.call(_rope, RopeChange(
        start: offset - 1,
        end: offset,
        text: '',
        deletedText: deleted,
      ));
      
      _updateTextInputState();
    }
    sw.stop();
    print('Backspace took ${sw.elapsedMicroseconds}µs');
  }

  /// Deletes one character after cursor (delete key).
  void deleteForward() {
    if (readOnly) return;
    
    final sw = Stopwatch()..start();
    
    if (hasSelection) {
      deleteSelection();
      sw.stop();
      return;
    }
    
    if (_selection.baseOffset < _rope.length) {
      _recordHistory();
      
      final offset = _selection.baseOffset;
      final deleted = _rope.substring(offset, offset + 1);
      _rope = _rope.delete(offset, offset + 1);
      // Cursor stays in place
      
      notifyListeners();
      onChanged?.call(_rope, RopeChange(
        start: offset,
        end: offset + 1,
        text: '',
        deletedText: deleted,
      ));
      
      _updateTextInputState();
    }
    sw.stop();
    print('Delete forward took ${sw.elapsedMicroseconds}µs');
  }

  /// Replaces the selection with new text.
  void replaceSelection(String text) {
    if (readOnly) return;
    
    _recordHistory(forceNew: true);
    
    final start = _selection.start;
    final end = _selection.end;
    final deleted = _rope.substring(start, end);
    
    _rope = _rope.replace(start, end, text);
    _selection = TextSelection.collapsed(offset: start + text.length);
    
    notifyListeners();
    onChanged?.call(_rope, RopeChange(
      start: start,
      end: end,
      text: text,
      deletedText: deleted,
    ));
    
    _updateTextInputState();
  }

  // ============================================================
  // Selection & Cursor Movement
  // ============================================================

  /// Sets the selection.
  void setSelection(TextSelection newSelection) {
    final clampedBase = newSelection.baseOffset.clamp(0, _rope.length);
    final clampedExtent = newSelection.extentOffset.clamp(0, _rope.length);
    
    _selection = TextSelection(
      baseOffset: clampedBase,
      extentOffset: clampedExtent,
      affinity: newSelection.affinity,
      isDirectional: newSelection.isDirectional,
    );
    
    _updateTextInputState();
    notifyListeners();
  }

  /// Moves cursor by delta characters.
  void moveCursor(int delta, {bool extend = false}) {
    final newOffset = (cursorOffset + delta).clamp(0, _rope.length);
    
    if (extend) {
      _selection = TextSelection(
        baseOffset: _selection.baseOffset,
        extentOffset: newOffset,
      );
    } else {
      _selection = TextSelection.collapsed(offset: newOffset);
    }
    
    _updateTextInputState();
    notifyListeners();
  }

  /// Moves cursor to start of line.
  void moveCursorToLineStart({bool extend = false}) {
    final lineIndex = _rope.lineIndexAt(cursorOffset);
    final lineStart = _rope.lineStartOffset(lineIndex);
    
    if (extend) {
      _selection = TextSelection(
        baseOffset: _selection.baseOffset,
        extentOffset: lineStart,
      );
    } else {
      _selection = TextSelection.collapsed(offset: lineStart);
    }
    
    _updateTextInputState();
    notifyListeners();
  }

  /// Moves cursor to end of line.
  void moveCursorToLineEnd({bool extend = false}) {
    final lineIndex = _rope.lineIndexAt(cursorOffset);
    final lineEnd = _rope.lineEndOffset(lineIndex);
    // Don't include the newline character
    final adjustedEnd = lineEnd > 0 && lineIndex < _rope.lineCount - 1 
        ? lineEnd - 1 
        : lineEnd;
    
    if (extend) {
      _selection = TextSelection(
        baseOffset: _selection.baseOffset,
        extentOffset: adjustedEnd,
      );
    } else {
      _selection = TextSelection.collapsed(offset: adjustedEnd);
    }
    
    _updateTextInputState();
    notifyListeners();
  }

  /// Moves cursor up one line.
  void moveCursorUp({bool extend = false}) {
    final currentLine = _rope.lineIndexAt(cursorOffset);
    if (currentLine == 0) return;
    
    final currentLineStart = _rope.lineStartOffset(currentLine);
    final columnOffset = cursorOffset - currentLineStart;
    
    final prevLineStart = _rope.lineStartOffset(currentLine - 1);
    final prevLine = _rope.getLine(currentLine - 1);
    final newOffset = prevLineStart + columnOffset.clamp(0, prevLine.length);
    
    if (extend) {
      _selection = TextSelection(
        baseOffset: _selection.baseOffset,
        extentOffset: newOffset,
      );
    } else {
      _selection = TextSelection.collapsed(offset: newOffset);
    }
    
    _updateTextInputState();
    notifyListeners();
  }

  /// Moves cursor down one line.
  void moveCursorDown({bool extend = false}) {
    final currentLine = _rope.lineIndexAt(cursorOffset);
    if (currentLine >= _rope.lineCount - 1) return;
    
    final currentLineStart = _rope.lineStartOffset(currentLine);
    final columnOffset = cursorOffset - currentLineStart;
    
    final nextLineStart = _rope.lineStartOffset(currentLine + 1);
    final nextLine = _rope.getLine(currentLine + 1);
    final newOffset = nextLineStart + columnOffset.clamp(0, nextLine.length);
    
    if (extend) {
      _selection = TextSelection(
        baseOffset: _selection.baseOffset,
        extentOffset: newOffset,
      );
    } else {
      _selection = TextSelection.collapsed(offset: newOffset);
    }
    
    _updateTextInputState();
    notifyListeners();
  }

  /// Selects all text.
  void selectAll() {
    _selection = TextSelection(baseOffset: 0, extentOffset: _rope.length);
    _updateTextInputState();
    notifyListeners();
  }

  // ============================================================
  // TextInputClient Implementation
  // ============================================================

  /// Attaches to the text input system.
  void attachTextInput() {
    if (_textInputConnection != null && _textInputConnection!.attached) {
      return;
    }
    
    _textInputConnection = TextInput.attach(
      this,
      const TextInputConfiguration(
        inputType: TextInputType.multiline,
        inputAction: TextInputAction.newline,
        enableSuggestions: false,
        autocorrect: false,
      ),
    );
    _textInputConnection!.show();
    _updateTextInputState();
  }

  /// Detaches from the text input system.
  void detachTextInput() {
    _textInputConnection?.close();
    _textInputConnection = null;
  }

  // Optimize IME for large files by syncing only a window around the cursor.
  // 1MB threshold.
  static const int kMaxSyncLength = 1024 * 1024;
  static const int kWindowSize = 512;

  void _updateTextInputState() {
    if (_textInputConnection == null || !_textInputConnection!.attached) {
      return;
    }
    
    if (_rope.length > kMaxSyncLength) {
       _updateTextInputStateWindowed();
       return;
    }
    
    _textInputConnection!.setEditingState(TextEditingValue(
      text: _rope.toString(),
      selection: _selection,
    ));
  }
  
  void _updateTextInputStateWindowed() {
      // Create a window around the cursor
      final start = (_selection.baseOffset - kWindowSize).clamp(0, _rope.length).toInt();
      final end = (_selection.extentOffset + kWindowSize).clamp(0, _rope.length).toInt();
      
      // Extract window text
      // Note: We use substring(start, end).
      // substring uses slice internally and returns String.
      final windowText = _rope.substring(start, end);
      
      // Map global selection to window local selection
      final localBase = _selection.baseOffset - start;
      final localExtent = _selection.extentOffset - start;
      
      // Ensure we don't produce invalid range due to race conditions or clamping differences,
      // though clamp above should handle it.
      final validBase = localBase.clamp(0, windowText.length).toInt();
      final validExtent = localExtent.clamp(0, windowText.length).toInt();
      
      _textInputConnection!.setEditingState(TextEditingValue(
        text: windowText,
        selection: TextSelection(
            baseOffset: validBase,
            extentOffset: validExtent,
            affinity: _selection.affinity,
            isDirectional: _selection.isDirectional,
        ),
        // We might want to set composing range too if needed.
        composing: TextRange.empty, 
      ));
  }

  @override
  TextEditingValue? get currentTextEditingValue {
      if (_rope.length > kMaxSyncLength) {
          // Return windowed value matching what we pushed to state
          final start = (_selection.baseOffset - kWindowSize).clamp(0, _rope.length).toInt();
          final end = (_selection.extentOffset + kWindowSize).clamp(0, _rope.length).toInt();
          final windowText = _rope.substring(start, end);
          final localBase = (_selection.baseOffset - start).clamp(0, windowText.length).toInt();
          final localExtent = (_selection.extentOffset - start).clamp(0, windowText.length).toInt();
          
          return TextEditingValue(
            text: windowText,
            selection: TextSelection(baseOffset: localBase, extentOffset: localExtent),
          );
      }
      return TextEditingValue(
        text: _rope.toString(),
        selection: _selection,
      );
  }

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    if (readOnly) return;
    
    // Diff the value to determine what changed
    final oldText = _rope.toString();
    final newText = value.text;
    
    if (oldText != newText) {
      // Text changed - reconstruct rope
      _rope = Rope(newText);
      onChanged?.call(_rope, null);
    }
    
    _selection = value.selection;
    notifyListeners();
  }

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline) {
      insertText('\n');
    }
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // Not used
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // Not used for desktop
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // Not used
  }

  @override
  void connectionClosed() {
    _textInputConnection = null;
  }

  @override
  void insertTextPlaceholder(Size size) {
    // Not used
  }

  @override
  void removeTextPlaceholder() {
    // Not used
  }

  @override
  void showToolbar() {
    // Could show context menu
  }

  @override
  void performSelector(String selectorName) {
    // macOS specific
  }

  @override
  void insertContent(KeyboardInsertedContent content) {
    // For rich content insertion (images, etc)
  }

  @override
  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {
    // Input control changed
  }

  @override
  void dispose() {
    detachTextInput();
    super.dispose();
  }
}

class _HistoryEntry {
  final Rope rope;
  final TextSelection selection;
  final DateTime timestamp;

  _HistoryEntry(this.rope, this.selection) : timestamp = DateTime.now();
}

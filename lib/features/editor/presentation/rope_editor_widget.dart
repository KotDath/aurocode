import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/diagnostics_provider.dart';
import '../application/rope_editor_controller.dart';
import '../domain/entities/highlight_theme.dart';
import '../domain/entities/highlight_token.dart';
import '../domain/entities/line_decoration.dart';
import '../domain/entities/rope.dart';
import '../domain/highlight_provider.dart';

/// A code editor widget that renders text from a [Rope] via [RopeEditorController].
/// 
/// Supports:
/// - Text display with viewport culling
/// - Keyboard input and editing
/// - Cursor rendering with blinking
/// - Selection rendering
/// - Line numbers
class RopeEditorWidget extends ConsumerStatefulWidget {
  /// The controller managing editor state.
  final RopeEditorController controller;
  
  /// Text style for the editor content.
  final TextStyle? textStyle;
  
  /// Background color.
  final Color? backgroundColor;
  
  /// Whether to show line numbers.
  final bool showLineNumbers;
  
  /// Line number text style.
  final TextStyle? lineNumberStyle;
  
  /// Gutter width for line numbers.
  final double gutterWidth;
  
  /// Padding around the text.
  final EdgeInsets padding;
  
  /// Cursor color.
  final Color cursorColor;
  
  /// Selection color.
  final Color selectionColor;
  
  /// Optional highlight provider for syntax highlighting.
  final HighlightProvider? highlightProvider;
  
  /// Highlight theme.
  final HighlightTheme highlightTheme;
  
  /// Language identifier for highlighting.
  final String? language;
  
  /// File path for LSP features.
  final String? filePath;
  
  /// Whether LSP is initialized and ready.
  final bool lspReady;

  const RopeEditorWidget({
    super.key,
    required this.controller,
    this.textStyle,
    this.backgroundColor,
    this.showLineNumbers = true,
    this.lineNumberStyle,
    this.gutterWidth = 60,
    this.padding = const EdgeInsets.all(8),
    this.cursorColor = Colors.white,
    this.selectionColor = const Color(0x40FFFFFF),
    this.highlightProvider,
    this.highlightTheme = HighlightTheme.atomOneDark,
    this.language,
    this.filePath,
    this.lspReady = false,
  });
  
  /// Creates a read-only widget from a raw Rope.
  factory RopeEditorWidget.readOnly({
    Key? key,
    required Rope rope,
    TextStyle? textStyle,
    Color? backgroundColor,
    bool showLineNumbers = true,
    TextStyle? lineNumberStyle,
    double gutterWidth = 60,
    EdgeInsets padding = const EdgeInsets.all(8),
  }) {
    return RopeEditorWidget(
      key: key,
      controller: RopeEditorController.fromRope(rope: rope, readOnly: true),
      textStyle: textStyle,
      backgroundColor: backgroundColor,
      showLineNumbers: showLineNumbers,
      lineNumberStyle: lineNumberStyle,
      gutterWidth: gutterWidth,
      padding: padding,
    );
  }

  @override
  ConsumerState<RopeEditorWidget> createState() => _RopeEditorWidgetState();
}

class _RopeEditorWidgetState extends ConsumerState<RopeEditorWidget> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  final FocusNode _focusNode = FocusNode();
  
  // Cursor blink timer
  Timer? _cursorBlinkTimer;
  bool _cursorVisible = true;
  
  // Cached metrics
  double _lineHeight = 20.0;
  double _charWidth = 10.0;
  
  // Drag selection state
  bool _isDragging = false;
  int _dragStartOffset = 0;
  
  // Multi-click tracking
  int _clickCount = 0;
  DateTime _lastClickTime = DateTime(0);
  Offset _lastClickPosition = Offset.zero;
  static const _multiClickTimeout = Duration(milliseconds: 400);
  static const _multiClickRadius = 5.0;
  
  // Syntax highlighting
  List<HighlightToken>? _highlightTokens;
  Timer? _highlightDebounceTimer;
  String? _lastHighlightedContent;
  
  // Search bar state
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _calculateMetrics();
    widget.controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);

    _requestHighlight();
    _verticalScrollController.addListener(_onScroll);
  }
  
  @override
  void didUpdateWidget(RopeEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textStyle != widget.textStyle) {
      _calculateMetrics();
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.highlightProvider != widget.highlightProvider ||
        oldWidget.language != widget.language ||
        oldWidget.filePath != widget.filePath ||
        oldWidget.lspReady != widget.lspReady) {
      
      // If LSP became ready, force re-highlight
      if (!oldWidget.lspReady && widget.lspReady) {
        _lastHighlightedContent = null;
      }
      
      _requestHighlight();
    }
  }
  
  void _onControllerChanged() {
    setState(() {});
    _resetCursorBlink();
    _requestHighlightDebounced();
  }

  void _onScroll() {
    if (widget.highlightProvider?.prefersWindowedUpdates ?? false) {
      _requestHighlightDebounced();
    }
  }
  
  void _requestHighlightDebounced() {
    _highlightDebounceTimer?.cancel();
    _highlightDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      _requestHighlight();
    });
  }
  
  void _requestHighlight() async {
    final provider = widget.highlightProvider;
    final language = widget.language;
    if (provider == null || language == null) return;
    
    final rope = widget.controller.rope;
    
    // Determine visible range if provider supports windowing
    int? visibleStart;
    int? visibleEnd;
    
    if (provider.prefersWindowedUpdates) {
       try {
         if (_verticalScrollController.hasClients) {
            final viewportTop = _verticalScrollController.offset;
            final viewportHeight = _verticalScrollController.position.viewportDimension;
            
            final maxLineIndex = rope.isEmpty ? 0 : rope.lineCount - 1;
            final firstLine = (viewportTop / _lineHeight).floor().clamp(0, maxLineIndex);
            final lastLine = ((viewportTop + viewportHeight) / _lineHeight).ceil().clamp(0, maxLineIndex);
            
            if (rope.isNotEmpty) {
              visibleStart = rope.lineStartOffset(firstLine);
              visibleEnd = rope.lineEndOffset(lastLine > firstLine ? lastLine : firstLine); 
            } else {
              visibleStart = 0;
              visibleEnd = 0;
            } 
         }
       } catch (_) {
         // Scroll controller might not be ready
       }
    }
    
    // For simple change detection without full string comparison:
    // We can use rope.completion / length / modification count check if available.
    // Or just rely on the controller notifying us.
    // But we need to avoid re-highlighting if nothing changed AND window didn't change (for windowed).
    
    // Construct a key for cache check
    final currentKey = '${rope.length}_${rope.hashCode}_${visibleStart}_$visibleEnd';
    if (currentKey == _lastHighlightedContent) return;
    
    _lastHighlightedContent = currentKey;
    
    try {
      final tokens = await provider.highlight(
        rope, 
        language, 
        filePath: widget.filePath,
        visibleStart: visibleStart,
        visibleEnd: visibleEnd,
      );
      
      if (mounted && widget.controller.rope == rope) {
        setState(() {
          _highlightTokens = tokens;
        });
      }
    } catch (_) {
      // Ignore errors
    }
  }
  
  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      widget.controller.attachTextInput();
      _startCursorBlink();
    } else {
      widget.controller.detachTextInput();
      _stopCursorBlink();
    }
    setState(() {});
  }
  
  void _startCursorBlink() {
    _stopCursorBlink();
    _cursorVisible = true;
    _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      setState(() {
        _cursorVisible = !_cursorVisible;
      });
    });
  }
  
  void _stopCursorBlink() {
    _cursorBlinkTimer?.cancel();
    _cursorBlinkTimer = null;
    _cursorVisible = true;
  }
  
  void _resetCursorBlink() {
    if (_focusNode.hasFocus) {
      _cursorVisible = true;
      _startCursorBlink();
    }
  }
  
  void _calculateMetrics() {
    final style = widget.textStyle ?? _defaultTextStyle;
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    
    _lineHeight = painter.height;
    _charWidth = painter.width;
    painter.dispose();
  }
  
  TextStyle get _defaultTextStyle => const TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 14,
    height: 1.5,
    color: Colors.white,
  );
  
  @override
  void dispose() {
    _stopCursorBlink();
    _highlightDebounceTimer?.cancel();

    widget.controller.removeListener(_onControllerChanged);
    _verticalScrollController.removeListener(_onScroll);
    _focusNode.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        _searchFocusNode.requestFocus();
        // Pre-populate with selected text
        if (widget.controller.hasSelection) {
          final sel = widget.controller.selection;
          final text = widget.controller.rope.substring(sel.start, sel.end);
          if (!text.contains('\n')) {
            _searchController.text = text;
            _searchController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: text.length,
            );
            _performSearch();
          }
        }
      } else {
        _focusNode.requestFocus();
        widget.controller.clearSearch();
      }
    });
  }
  
  void _closeSearchBar() {
    setState(() {
      _showSearchBar = false;
      _focusNode.requestFocus();
      widget.controller.clearSearch();
    });
  }
  
  void _performSearch() {
    widget.controller.search(_searchController.text);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    
    final controller = widget.controller;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isModifier = isCtrl || isMeta;
    
    // Navigation
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (isModifier) {
        // Word movement (simplified: just move to line start)
        controller.moveCursorToLineStart(extend: isShift);
      } else {
        controller.moveCursor(-1, extend: isShift);
      }
      return KeyEventResult.handled;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (isModifier) {
        controller.moveCursorToLineEnd(extend: isShift);
      } else {
        controller.moveCursor(1, extend: isShift);
      }
      return KeyEventResult.handled;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      controller.moveCursorUp(extend: isShift);
      return KeyEventResult.handled;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      controller.moveCursorDown(extend: isShift);
      return KeyEventResult.handled;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.home) {
      controller.moveCursorToLineStart(extend: isShift);
      return KeyEventResult.handled;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.end) {
      controller.moveCursorToLineEnd(extend: isShift);
      return KeyEventResult.handled;
    }
    
    // Editing
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      controller.deleteBackward();
      return KeyEventResult.handled;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.delete) {
      controller.deleteForward();
      return KeyEventResult.handled;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      controller.insertText('\n');
      return KeyEventResult.handled;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      controller.insertText('  '); // 2 spaces
      return KeyEventResult.handled;
    }
    
    // Select all
    if (isModifier && event.logicalKey == LogicalKeyboardKey.keyA) {
      controller.selectAll();
      return KeyEventResult.handled;
    }
    
    // Copy (Ctrl+C)
    if (isModifier && event.logicalKey == LogicalKeyboardKey.keyC) {
      _copy();
      return KeyEventResult.handled;
    }
    
    // Cut (Ctrl+X)
    if (isModifier && event.logicalKey == LogicalKeyboardKey.keyX) {
      _cut();
      return KeyEventResult.handled;
    }
    
    // Paste (Ctrl+V)
    if (isModifier && event.logicalKey == LogicalKeyboardKey.keyV) {
      _paste();
      return KeyEventResult.handled;
    }
    
    // Undo
    if (isModifier && event.logicalKey == LogicalKeyboardKey.keyZ && !isShift) {
      controller.undo();
      return KeyEventResult.handled;
    }
    
    // Redo (Ctrl+Y or Ctrl+Shift+Z)
    if (isModifier && event.logicalKey == LogicalKeyboardKey.keyY) {
      controller.redo();
      return KeyEventResult.handled;
    }
    if (isModifier && event.logicalKey == LogicalKeyboardKey.keyZ && isShift) {
      controller.redo();
      return KeyEventResult.handled;
    }
    
    // Find (Ctrl+F)
    if (isModifier && event.logicalKey == LogicalKeyboardKey.keyF) {
      _toggleSearchBar();
      return KeyEventResult.handled;
    }
    
    // Find next (F3 or Enter in search)
    if (event.logicalKey == LogicalKeyboardKey.f3) {
      if (isShift) {
        controller.findPrev();
      } else {
        controller.findNext();
      }
      return KeyEventResult.handled;
    }
    
    // Escape closes search
    if (event.logicalKey == LogicalKeyboardKey.escape && _showSearchBar) {
      _closeSearchBar();
      return KeyEventResult.handled;
    }
    
    // Regular character input (let IME handle it mostly)
    if (event.character != null && 
        event.character!.isNotEmpty && 
        !isModifier &&
        event.character!.codeUnitAt(0) >= 32) {
      controller.insertText(event.character!);
      return KeyEventResult.handled;
    }
    
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.textStyle ?? _defaultTextStyle;
    final lineNumberStyle = widget.lineNumberStyle ?? textStyle.copyWith(
      color: Colors.grey,
    );
    final rope = widget.controller.rope;
    
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTapDown: (details) {
          _focusNode.requestFocus();
          _handleTapDown(details.localPosition);
        },
        onPanStart: (details) {
          _handleDragStart(details.localPosition);
        },
        onPanUpdate: (details) {
          _handleDragUpdate(details.localPosition);
        },
        onPanEnd: (_) {
          _handleDragEnd();
        },
        child: Column(
          children: [
            // Search bar
            if (_showSearchBar)
              _SearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                matchCount: widget.controller.searchMatches.length,
                currentMatch: widget.controller.currentMatchIndex,
                onChanged: (_) => _performSearch(),
                onNext: () => widget.controller.findNext(),
                onPrev: () => widget.controller.findPrev(),
                onClose: _closeSearchBar,
              ),
            // Editor
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _EditorBody(
                    rope: rope,
                    selection: widget.controller.selection,
                    textStyle: textStyle,
                    lineNumberStyle: lineNumberStyle,
                    showLineNumbers: widget.showLineNumbers,
                    gutterWidth: widget.gutterWidth,
                    padding: widget.padding,
                    lineHeight: _lineHeight,
                    charWidth: _charWidth,
                    verticalScrollController: _verticalScrollController,
                    horizontalScrollController: _horizontalScrollController,
                    viewportHeight: constraints.maxHeight,
                    viewportWidth: constraints.maxWidth,
                    cursorColor: widget.cursorColor,
                    selectionColor: widget.selectionColor,
                    showCursor: _focusNode.hasFocus && _cursorVisible,
                    hasFocus: _focusNode.hasFocus,
                    highlightTokens: _highlightTokens,
                    highlightTheme: widget.highlightTheme,
                    searchMatches: widget.controller.searchMatches,
                    currentMatchIndex: widget.controller.currentMatchIndex,
                    lineDecorations: _getLineDecorations(ref),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get line decorations from diagnostics provider.
  List<LineDecoration> _getLineDecorations(WidgetRef ref) {
    if (widget.filePath == null) return const [];
    
    final diagnosticsState = ref.watch(diagnosticsProvider);
    final diagnostics = diagnosticsState.forFile(widget.filePath!);
    
    if (diagnostics.isEmpty) return const [];
    
    // Convert diagnostics to decorations
    return diagnosticsToDecorations(
      diagnostics,
      widget.controller.rope.toString(),
    );
  }

  /// Copy selected text to clipboard.
  void _copy() {
    final selection = widget.controller.selection;
    if (selection.isCollapsed) return;
    
    final text = widget.controller.rope.substring(
      selection.start,
      selection.end,
    );
    Clipboard.setData(ClipboardData(text: text));
  }

  /// Cut selected text to clipboard.
  void _cut() {
    if (widget.controller.readOnly) return;
    
    final selection = widget.controller.selection;
    if (selection.isCollapsed) return;
    
    _copy();
    widget.controller.deleteSelection();
  }

  /// Paste text from clipboard.
  Future<void> _paste() async {
    if (widget.controller.readOnly) return;
    
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      widget.controller.insertText(data.text!);
    }
  }
  
  int _positionToOffset(Offset position) {
    final effectiveGutterWidth = widget.showLineNumbers ? widget.gutterWidth : 0.0;
    final contentX = position.dx - effectiveGutterWidth;
    final contentY = position.dy + _verticalScrollController.offset;
    
    if (contentX < 0 || widget.controller.rope.isEmpty) return 0;
    
    final lineCount = widget.controller.lineCount;
    final lineIndex = ((contentY - widget.padding.top) / _lineHeight)
        .floor()
        .clamp(0, lineCount > 0 ? lineCount - 1 : 0);
    
    final lineStart = widget.controller.rope.lineStartOffset(lineIndex);
    final lineText = widget.controller.rope.getLine(lineIndex);
    final column = ((contentX - widget.padding.left + _horizontalScrollController.offset) / _charWidth)
        .round()
        .clamp(0, lineText.length);
    
    return lineStart + column;
  }
  
  void _handleTapDown(Offset position) {
    final now = DateTime.now();
    final distance = (position - _lastClickPosition).distance;
    
    // Check if this is a multi-click
    if (now.difference(_lastClickTime) < _multiClickTimeout && distance < _multiClickRadius) {
      _clickCount++;
    } else {
      _clickCount = 1;
    }
    
    _lastClickTime = now;
    _lastClickPosition = position;
    
    final offset = _positionToOffset(position);
    
    if (_clickCount == 1) {
      // Single click - position cursor
      widget.controller.setSelection(TextSelection.collapsed(offset: offset));
    } else if (_clickCount == 2) {
      // Double click - select word
      _selectWordAt(offset);
    } else if (_clickCount >= 3) {
      // Triple click - select line
      _selectLineAt(offset);
      _clickCount = 0; // Reset after triple
    }
  }
  
  void _selectWordAt(int offset) {
    final text = widget.controller.rope.toString();
    if (text.isEmpty) return;
    
    // Find word boundaries
    var start = offset;
    var end = offset;
    
    // Expand left
    while (start > 0 && _isWordChar(text[start - 1])) {
      start--;
    }
    
    // Expand right
    while (end < text.length && _isWordChar(text[end])) {
      end++;
    }
    
    if (start != end) {
      widget.controller.setSelection(TextSelection(baseOffset: start, extentOffset: end));
    }
  }
  
  void _selectLineAt(int offset) {
    final rope = widget.controller.rope;
    if (rope.isEmpty) return;
    
    final lineIndex = rope.lineIndexAt(offset);
    final lineStart = rope.lineStartOffset(lineIndex);
    final lineEnd = rope.lineEndOffset(lineIndex);
    
    widget.controller.setSelection(TextSelection(baseOffset: lineStart, extentOffset: lineEnd));
  }
  
  bool _isWordChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||   // 0-9
           (code >= 65 && code <= 90) ||   // A-Z
           (code >= 97 && code <= 122) ||  // a-z
           code == 95;                      // _
  }
  
  void _handleDragStart(Offset position) {
    _isDragging = true;
    _dragStartOffset = _positionToOffset(position);
    widget.controller.setSelection(TextSelection.collapsed(offset: _dragStartOffset));
  }
  
  void _handleDragUpdate(Offset position) {
    if (!_isDragging) return;
    
    final currentOffset = _positionToOffset(position);
    widget.controller.setSelection(TextSelection(
      baseOffset: _dragStartOffset,
      extentOffset: currentOffset,
    ));
  }
  
  void _handleDragEnd() {
    _isDragging = false;
  }
}

class _EditorBody extends StatelessWidget {
  final Rope rope;
  final TextSelection selection;
  final TextStyle textStyle;
  final TextStyle lineNumberStyle;
  final bool showLineNumbers;
  final double gutterWidth;
  final EdgeInsets padding;
  final double lineHeight;
  final double charWidth;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final double viewportHeight;
  final double viewportWidth;
  final Color cursorColor;
  final Color selectionColor;
  final bool showCursor;
  final bool hasFocus;
  final List<HighlightToken>? highlightTokens;
  final HighlightTheme highlightTheme;
  final List<(int, int)> searchMatches;
  final int currentMatchIndex;
  final List<LineDecoration> lineDecorations;

  const _EditorBody({
    required this.rope,
    required this.selection,
    required this.textStyle,
    required this.lineNumberStyle,
    required this.showLineNumbers,
    required this.gutterWidth,
    required this.padding,
    required this.lineHeight,
    required this.charWidth,
    required this.verticalScrollController,
    required this.horizontalScrollController,
    required this.viewportHeight,
    required this.viewportWidth,
    required this.cursorColor,
    required this.selectionColor,
    required this.showCursor,
    required this.hasFocus,
    required this.highlightTokens,
    required this.highlightTheme,
    required this.searchMatches,
    required this.currentMatchIndex,
    required this.lineDecorations,
  });

  @override
  Widget build(BuildContext context) {
    final lineCount = rope.isEmpty ? 1 : rope.lineCount;
    final totalHeight = lineCount * lineHeight + padding.vertical;
    final maxLineLength = _computeMaxLineLength();
    final totalWidth = maxLineLength * charWidth + padding.horizontal;
    
    // In Unified Scroll Architecture:
    // We use ONE outer Vertical ScrollView.
    // Inside it, we have a Row(Gutter, Content).
    // The Content is wrapped in a Horizontal ScrollView.
    // Ensure totalHeight is propagated.
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce valid constraints for the CustomPaint
        final viewportHeight = constraints.maxHeight;
        final viewportWidth = constraints.maxWidth;
        
        return Stack(
          children: [
            // Layer 1: Renderer (Pinned to viewport, essentially a virtual window)
            // We use RepaintBoundary to isolate the paint layer.
            // We use CustomPaint with the size of the viewport.
            // The Painter will need to subtract 'scrollOffset' from Y coordinates.
            Positioned(
              left: showLineNumbers ? gutterWidth : 0, 
              top: 0, 
              bottom: 0,
              right: 0,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: Listenable.merge([verticalScrollController, horizontalScrollController]),
                  builder: (context, _) {
                    return Transform.translate(
                      offset: Offset(-(horizontalScrollController.hasClients ? horizontalScrollController.offset : 0.0), 0),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size(totalWidth, viewportHeight),
                          painter: _RopeTextPainter(
                            rope: rope,
                            selection: selection,
                            textStyle: textStyle,
                            lineHeight: lineHeight,
                            charWidth: charWidth,
                            padding: padding,
                            cursorColor: cursorColor,
                            selectionColor: selectionColor,
                            showCursor: showCursor,
                            highlightTokens: highlightTokens,
                            highlightTheme: highlightTheme,
                            searchMatches: searchMatches,
                            currentMatchIndex: currentMatchIndex,
                            lineDecorations: lineDecorations,
                            verticalScrollController: verticalScrollController,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Layer 2: Line Numbers Gutter (Pinned to left, simplified for now)
            // Ideally should be outside the horizontal scroll but inside vertical?
            // The Unified Architecture in plan puts Gutter *next* to Content.
            // If we use Stack, Gutter must also be virtualized or pinned.
            // Let's keep Gutter simple: Just a container on left.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: showLineNumbers ? gutterWidth : 0,
              child: showLineNumbers 
               ? Container(
                   color: const Color(0xFF1E1E1E), // Match editor bg
                   child: RepaintBoundary(
                     child: AnimatedBuilder(
                       animation: verticalScrollController,
                       builder: (context, _) => CustomPaint(
                         painter: _GutterPainter(
                           lineCount: lineCount,
                           lineHeight: lineHeight,
                           style: lineNumberStyle ?? const TextStyle(color: Colors.grey),
                           padding: padding,
                           verticalScrollController: verticalScrollController,
                         ),
                       )
                     ),
                   )
                 )
               : const SizedBox.shrink(),
            ),

            // Layer 3: Scroller for Interaction (no built-in scrollbars)
            Positioned.fill(
              left: showLineNumbers ? gutterWidth : 0,
              bottom: 14, // Room for horizontal scrollbar
              right: 12,  // Room for vertical scrollbar
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: verticalScrollController,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalWidth < viewportWidth ? viewportWidth : totalWidth,
                      height: totalHeight,
                    ),
                  ),
                ),
              ),
            ),
            
            // Layer 4a: Custom Vertical Scrollbar (pinned at right)
            Positioned(
              top: 0,
              right: 0,
              bottom: 14, // Room for horizontal scrollbar
              width: 12,
              child: _CustomVerticalScrollbar(
                controller: verticalScrollController,
                contentHeight: totalHeight,
                viewportHeight: viewportHeight - 14, // Minus horizontal scrollbar
              ),
            ),

            
            // Layer 4: Custom Horizontal Scrollbar (pinned at bottom)
            Positioned(
              left: showLineNumbers ? gutterWidth : 0,
              right: 12, // Leave room for vertical scrollbar
              bottom: 0,
              height: 14,
              child: _CustomHorizontalScrollbar(
                controller: horizontalScrollController,
                contentWidth: totalWidth,
                viewportWidth: viewportWidth - (showLineNumbers ? gutterWidth : 0) - 12, // Subtract gutter and vertical scrollbar
              ),
            ),

          ],
        );
      }
    );
  }
  
  int _computeMaxLineLength() {
    if (rope.isEmpty) return 80;
    
    var maxLen = 0;
    // Optimization disabled for correctness on user request
    // if (rope.lineCount > 2000) { ... }
    for (var i = 0; i < rope.lineCount; i++) {
        final lineLen = rope.getLine(i).length;
        if (lineLen > maxLen) maxLen = lineLen;
    }
    
    return maxLen < 80 ? 80 : maxLen;
  }
}

class _LineNumbersGutter extends StatelessWidget {
  final int lineCount;
  final double lineHeight;
  final TextStyle style;
  final EdgeInsets padding;
  final ScrollController verticalScrollController;

  const _LineNumbersGutter({
    required this.lineCount,
    required this.lineHeight,
    required this.style,
    required this.padding,
    required this.verticalScrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      width: 50, // Fixed width or passed from parent? passed as gutterWidth in parent
      child: CustomPaint(
        painter: _GutterPainter(
          lineCount: lineCount,
          lineHeight: lineHeight,
          style: style,
          padding: padding,
          verticalScrollController: verticalScrollController,
        ),
      ),
    );
  }
}

class _GutterPainter extends CustomPainter {
  final int lineCount;
  final double lineHeight;
  final TextStyle style;
  final EdgeInsets padding;
  final ScrollController verticalScrollController;

  _GutterPainter({
    required this.lineCount,
    required this.lineHeight,
    required this.style,
    required this.padding,
    required this.verticalScrollController,
  }) : super(repaint: verticalScrollController);

  @override
  void paint(Canvas canvas, Size size) {
    // Viewport culling
    final viewportTop = verticalScrollController.hasClients ? verticalScrollController.offset : 0.0;
    
    // NOTE: In the unified architecture, this CustomPaint will be inside the Vertical SingleChildScrollView.
    // So 'canvas' is ALREADY translated by -offset.
    // However, for the gutter to be "sticky" (fixed position), it shouldn't scroll?
    // WAIT. If it's in the Unified Vertical ScrollView, it scrolls UP with content.
    // This is correct: Lines 1, 2, 3 scroll up as content scrolls up.
    // So we just paint visible lines based on viewportTop.
    // BUT since we are inside the scroll view, the paint origin (0,0) is at the top of the SCROLLABLE area (which is huge).
    // So we just paint everything? No, CustomPaint usually clips or we want culling.
    // If we paint at (0, 0) relative to CustomPaint, and CustomPaint is huge (total height),
    // then Flutter's rasterizer handles clipping.
    // BUT we want to avoid LOOPING over 1 million lines.
    // So we calculate first/last visible lines based on viewportTop.
    
    final firstLine = (viewportTop / lineHeight).floor();
    double visibleHeight = 1000.0;
    try {
        if (verticalScrollController.hasClients) {
            visibleHeight = verticalScrollController.position.viewportDimension;
        }
    } catch (_) {}
    
    final lastLine = firstLine + (visibleHeight / lineHeight).ceil() + 1;
    
    final effectiveLastLine = (lastLine < lineCount) ? lastLine : lineCount - 1;
    
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = firstLine; i <= effectiveLastLine; i++) {
      if (i < 0) continue;
      
      textPainter.text = TextSpan(
        text: '${i + 1}',
        style: style,
      );
      textPainter.layout();
      
      final y = padding.top + i * lineHeight - viewportTop; // Fix: Subtract offset
      final x = size.width - textPainter.width - 8; // Right align with padding
      
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _GutterPainter oldDelegate) {
    return oldDelegate.lineCount != lineCount ||
           oldDelegate.verticalScrollController != verticalScrollController ||
           oldDelegate.style != style;
  }
}

/// Custom painter for rendering rope text with cursor, selection, and syntax highlighting.
class _RopeTextPainter extends CustomPainter {
  final Rope rope;
  final TextSelection selection;
  final TextStyle textStyle;
  final double lineHeight;
  final double charWidth;
  final EdgeInsets padding;
  final Color cursorColor;
  final Color selectionColor;
  final bool showCursor;
  final List<HighlightToken>? highlightTokens;
  final HighlightTheme highlightTheme;
  final List<(int, int)> searchMatches;
  final int currentMatchIndex;
  final List<LineDecoration> lineDecorations;
  final ScrollController verticalScrollController;
  final ScrollController? horizontalScrollController;

  _RopeTextPainter({
    required this.rope,
    required this.selection,
    required this.textStyle,
    required this.lineHeight,
    required this.charWidth,
    required this.padding,
    required this.cursorColor,
    required this.selectionColor,
    required this.showCursor,
    required this.highlightTokens,
    required this.highlightTheme,
    required this.searchMatches,
    required this.currentMatchIndex,
    required this.lineDecorations,
    required this.verticalScrollController,
    this.horizontalScrollController,
  }) : super(repaint: Listenable.merge([verticalScrollController, horizontalScrollController]));


  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Background (Clear previous frame artifacts)
    final bgPaint = Paint()..color = const Color(0xFF1E1E1E); 
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // We need clipBounds for culling logic below
    final clipBounds = canvas.getLocalClipBounds();

    if (rope.isEmpty) {
      if (showCursor) {
        _drawCursorAt(canvas, padding.left, padding.top);
      }
      return;
    }
    
    // Use ScrollController to determine visibility
    double viewportTop = 0.0;
    double viewportHeight = size.height;
    
    if (verticalScrollController.hasClients) {
        viewportTop = verticalScrollController.offset;
        viewportHeight = verticalScrollController.position.viewportDimension;
    }
    
    // Calculate visible lines based on viewport
    final firstVisibleLine = (viewportTop / lineHeight).floor().clamp(0, rope.lineCount - 1);
    final lastVisibleLine = ((viewportTop + viewportHeight) / lineHeight).ceil().clamp(0, rope.lineCount - 1);

    // Calculate horizontal visibility (still use clipBounds for horizontal as it might be nested)
    final firstVisibleCol = ((clipBounds.left - padding.left) / charWidth).floor().clamp(0, 100000).toInt(); 
    final lastVisibleCol = ((clipBounds.right - padding.left) / charWidth).ceil().clamp(0, 100000).toInt();
    
    // Draw search match highlights (background)
    if (searchMatches.isNotEmpty) {
      _drawSearchMatches(canvas, firstVisibleLine, lastVisibleLine);
    }
    
    // Draw selection (background)
    if (selection.isValid && !selection.isCollapsed) {
      _drawSelection(canvas, firstVisibleLine, lastVisibleLine);
    }
    
    // Draw text with highlighting
    for (var i = firstVisibleLine; i <= lastVisibleLine; i++) {
      final y = padding.top + i * lineHeight - verticalScrollController.offset;
      
      // Calculate start world offset for this lineStartOffset(i);
      final lineStart = rope.lineStartOffset(i);
      var lineEnd = rope.lineEndOffset(i);
      
      // Exclude newline from lineEnd if present
      if (lineEnd > lineStart) {
        if (rope.charAt(lineEnd - 1) == '\n') {
          lineEnd--;
        }
      }
      
      final lineLength = lineEnd - lineStart;
      if (lineLength <= 0) continue;

      // Draw full line (no horizontal clipping for correctness)
      final lineText = rope.substring(lineStart, lineEnd);
      final spans = _buildSpansForLineClipped(
          lineText, 
          lineStart,
          highlightTokens ?? []
      );
      
      final textPainter = TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: double.infinity); 
      
      textPainter.paint(canvas, Offset(padding.left, y));
      textPainter.dispose();
    }
    
    // Draw line decorations (diagnostics, etc.)
    if (lineDecorations.isNotEmpty) {
      _drawLineDecorations(canvas, firstVisibleLine, lastVisibleLine);
    }
    
    // Draw cursor
    if (showCursor && selection.isCollapsed) {
      final cursorOffset = selection.baseOffset;
      final lineIndex = rope.lineIndexAt(cursorOffset);
      
      // Calculate cursor position by measuring text width to handle non-monospace fonts or fallbacks
      final lineStart = rope.lineStartOffset(lineIndex);
      final lineEnd = rope.lineEndOffset(lineIndex);
      // Ensure we don't read past the line end or file end
      final safeLineEnd = (lineEnd > rope.length) ? rope.length : lineEnd;
      // Get the text on the line up to the cursor
      // We need the full line content to handle tabs properly usually, but for now specific prefix measure is safer than charWidth * col
      final currentLineText = rope.substring(lineStart, safeLineEnd);
      
      final column = cursorOffset - lineStart;
      final safeColumn = column.clamp(0, currentLineText.length);
      final textBeforeCursor = currentLineText.substring(0, safeColumn);
      
      final textPainter = TextPainter(
        text: TextSpan(text: textBeforeCursor, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      
      final x = padding.left + textPainter.width;
      final y = padding.top + lineIndex * lineHeight - (verticalScrollController.offset);
      
      _drawCursorAt(canvas, x, y);
    }
  }
  
  void _drawCursorAt(Canvas canvas, double x, double y) {
    final paint = Paint()
      ..color = cursorColor
      ..strokeWidth = 2;
      
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + lineHeight),
      paint,
    );
  }

  /// Draws line decorations (wavy underlines for errors, etc.)
  void _drawLineDecorations(Canvas canvas, int firstLine, int lastLine) {
    for (final decoration in lineDecorations) {
      // Skip if decoration is outside visible range
      final decorStartLine = rope.lineIndexAt(decoration.start.clamp(0, rope.length - 1));
      final decorEndLine = rope.lineIndexAt(decoration.end.clamp(0, rope.length - 1));
      
      if (decorEndLine < firstLine || decorStartLine > lastLine) continue;
      
      // Draw on each visible line
      for (var lineIdx = decorStartLine; lineIdx <= decorEndLine && lineIdx >= firstLine && lineIdx <= lastLine; lineIdx++) {
        final lineStart = rope.lineStartOffset(lineIdx);
        var lineEnd = rope.lineEndOffset(lineIdx);
        if (lineEnd > lineStart && rope.charAt(lineEnd - 1) == '\n') lineEnd--;
        
        // Calculate decoration bounds on this line
        final decorStartOnLine = lineIdx == decorStartLine ? decoration.start - lineStart : 0;
        final decorEndOnLine = lineIdx == decorEndLine ? decoration.end - lineStart : lineEnd - lineStart;
        
        if (decorEndOnLine <= decorStartOnLine) continue;
        
        final x1 = padding.left + decorStartOnLine * charWidth;
        final x2 = padding.left + decorEndOnLine * charWidth;
        final y = padding.top + lineIdx * lineHeight - verticalScrollController.offset + lineHeight - 2;
        
        if (decoration.type == LineDecorationType.wavyUnderline) {
          _drawWavyLine(canvas, x1, x2, y, decoration.color, decoration.thickness);
        } else if (decoration.type == LineDecorationType.underline) {
          final paint = Paint()
            ..color = decoration.color
            ..strokeWidth = decoration.thickness
            ..style = PaintingStyle.stroke;
          canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
        }
      }
    }
  }
  
  /// Draws a wavy/squiggly line from x1 to x2 at y.
  void _drawWavyLine(Canvas canvas, double x1, double x2, double y, Color color, double thickness) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    const waveHeight = 2.0;
    const waveLength = 4.0;
    
    path.moveTo(x1, y);
    
    var x = x1;
    var up = true;
    while (x < x2) {
      final nextX = (x + waveLength).clamp(x1, x2);
      final nextY = up ? y - waveHeight : y + waveHeight;
      path.lineTo(nextX, nextY);
      x = nextX;
      up = !up;
    }
    
    canvas.drawPath(path, paint);
  }

  /// Builds spans for a clipped substring of the line.
  /// [clippedText] is the substring.
  /// [absoluteStartOffset] is the global offset of the start of [clippedText].
  List<TextSpan> _buildSpansForLineClipped(String clippedText, int absoluteStartOffset, List<HighlightToken> allTokens) {
      if (allTokens.isEmpty) {
         return [TextSpan(text: clippedText, style: textStyle)];
      }

      final absoluteEndOffset = absoluteStartOffset + clippedText.length;
      
      // Binary search / filtering for relevant tokens
      // We want tokens that overlap with [absoluteStartOffset, absoluteEndOffset]
      // Simpler: Just reuse the binary search logic but filter strict bounds
      
      var left = 0;
      var right = allTokens.length - 1;
      var startIndex = -1;
      
      while (left <= right) {
        final mid = (left + right) ~/ 2;
        final token = allTokens[mid];
        
        if (token.end > absoluteStartOffset) {
           startIndex = mid;
           right = mid - 1;
        } else {
           left = mid + 1;
        }
      }
      
      if (startIndex == -1) {
         return [TextSpan(text: clippedText, style: textStyle)];
      }

      final spans = <TextSpan>[];
      var pos = 0; // Relative to clippedText
      
      for (var i = startIndex; i < allTokens.length; i++) {
         final token = allTokens[i];
         if (token.start >= absoluteEndOffset) break;
         
         // Intersect token with our clipped range
         // Token: [start, end)
         // Range: [absoluteStartOffset, absoluteEndOffset)
         
         final tokenOverlapStart = (token.start - absoluteStartOffset).clamp(0, clippedText.length);
         final tokenOverlapEnd = (token.end - absoluteStartOffset).clamp(0, clippedText.length);
         
         if (tokenOverlapStart > pos) {
             spans.add(TextSpan(text: clippedText.substring(pos, tokenOverlapStart), style: textStyle));
         }
         
         if (tokenOverlapEnd > tokenOverlapStart) {
             final tokenStyle = highlightTheme.getStyle(token.type, token.modifiers);
             spans.add(TextSpan(text: clippedText.substring(tokenOverlapStart, tokenOverlapEnd), style: textStyle.merge(tokenStyle)));
             pos = tokenOverlapEnd;
         }
      }
      
      if (pos < clippedText.length) {
          spans.add(TextSpan(text: clippedText.substring(pos), style: textStyle));
      }
      
      return spans.isEmpty ? [TextSpan(text: clippedText, style: textStyle)] : spans;
  }

  // Deprecated: _buildSpansForLine implementation replaced by _buildSpansForLineClipped logic inline
  // Keeping method signature compatibility if needed, but since it's private we can remove/replace logic.
  List<TextSpan> _buildSpansForLine(String lineText, int lineStart, int lineEnd) {
      // This is expected to be unused now, or can just refactor to use clipped logic with full range
      return _buildSpansForLineClipped(lineText, lineStart, highlightTokens ?? []);
  }
  
  void _drawSelection(Canvas canvas, int firstLine, int lastLine) {
    final paint = Paint()..color = selectionColor;
    final start = selection.start;
    final end = selection.end;
    
    final startLine = rope.lineIndexAt(start);
    final endLine = rope.lineIndexAt(end);
    
    for (var i = startLine; i <= endLine && i >= firstLine && i <= lastLine; i++) {
      final lineStart = rope.lineStartOffset(i);
      var lineEnd = rope.lineEndOffset(i);
      if (lineEnd > lineStart && rope.charAt(lineEnd - 1) == '\n') {
          lineEnd--;
      }
      final lineLength = lineEnd - lineStart;
      
      final selStart = i == startLine ? start - lineStart : 0;
      final selEnd = i == endLine ? end - lineStart : lineLength;
      
      final x1 = padding.left + selStart * charWidth;
      final x2 = padding.left + selEnd * charWidth;
      final y = padding.top + i * lineHeight - verticalScrollController.offset;
      
      canvas.drawRect(
        Rect.fromLTWH(x1, y, x2 - x1, lineHeight),
        paint,
      );
    }
    

  }
  
  void _drawSearchMatches(Canvas canvas, int firstLine, int lastLine) {
    final matchPaint = Paint()..color = const Color(0x60FFFF00); // Yellow semi-transparent
    final currentMatchPaint = Paint()..color = const Color(0x80FFA500); // Orange for current
    
    for (var i = 0; i < searchMatches.length; i++) {
      final (start, end) = searchMatches[i];
      final paint = i == currentMatchIndex ? currentMatchPaint : matchPaint;
      
      final startLine = rope.lineIndexAt(start);
      final endLine = rope.lineIndexAt(end);
      
      // Only draw if visible
      if (startLine > lastLine || endLine < firstLine) continue;
      
      for (var lineIdx = startLine; lineIdx <= endLine && lineIdx >= firstLine && lineIdx <= lastLine; lineIdx++) {
        final lineStart = rope.lineStartOffset(lineIdx);
        var lineEnd = rope.lineEndOffset(lineIdx);
        if (lineEnd > lineStart && rope.charAt(lineEnd - 1) == '\n') {
          lineEnd--;
        }
        final lineLength = lineEnd - lineStart;
        
        final matchStartInLine = lineIdx == startLine ? start - lineStart : 0;
        final matchEndInLine = lineIdx == endLine ? end - lineStart : lineLength;
        
        final x1 = padding.left + matchStartInLine * charWidth;
        final x2 = padding.left + matchEndInLine * charWidth;
        final y = padding.top + lineIdx * lineHeight - verticalScrollController.offset;
        
        canvas.drawRect(
          Rect.fromLTWH(x1, y, x2 - x1, lineHeight),
          paint,
        );
      }
    }
  }
  


  @override
  bool shouldRepaint(covariant _RopeTextPainter oldDelegate) {
    return oldDelegate.rope != rope ||
           oldDelegate.selection != selection ||
           oldDelegate.textStyle != textStyle ||
           oldDelegate.showCursor != showCursor ||
           oldDelegate.lineHeight != lineHeight ||
           oldDelegate.highlightTokens != highlightTokens ||
           oldDelegate.searchMatches != searchMatches ||
           oldDelegate.currentMatchIndex != currentMatchIndex;
  }
}

/// Search bar overlay widget.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int matchCount;
  final int currentMatch;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.matchCount,
    required this.currentMatch,
    required this.onChanged,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final matchText = matchCount > 0 
        ? '${currentMatch + 1}/$matchCount' 
        : 'No matches';
    
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF252526),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800),
        ),
      ),
      child: Row(
        children: [
          // Search input
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Find...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: onChanged,
              onSubmitted: (_) => onNext(),
            ),
          ),
          const SizedBox(width: 8),
          // Match count
          Text(
            matchText,
            style: TextStyle(
              color: matchCount > 0 ? Colors.grey.shade400 : Colors.red.shade300,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          // Navigation buttons
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            onPressed: matchCount > 0 ? onPrev : null,
            color: Colors.grey.shade400,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            onPressed: matchCount > 0 ? onNext : null,
            color: Colors.grey.shade400,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            color: Colors.grey.shade400,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }
}

/// Custom horizontal scrollbar that doesn't require a ScrollView child.
/// Uses the controller directly for position sync and GestureDetector for interaction.
class _CustomHorizontalScrollbar extends StatefulWidget {
  final ScrollController controller;
  final double contentWidth;
  final double viewportWidth;

  const _CustomHorizontalScrollbar({
    required this.controller,
    required this.contentWidth,
    required this.viewportWidth,
  });

  @override
  State<_CustomHorizontalScrollbar> createState() => _CustomHorizontalScrollbarState();
}

class _CustomHorizontalScrollbarState extends State<_CustomHorizontalScrollbar> {
  bool _isDragging = false;
  double _dragStartScrollOffset = 0;
  double _dragStartLocalX = 0;

  double get _maxScrollExtent => (widget.contentWidth - widget.viewportWidth).clamp(0, double.infinity);
  
  double get _thumbWidth {
    if (widget.contentWidth <= widget.viewportWidth) return widget.viewportWidth;
    final ratio = widget.viewportWidth / widget.contentWidth;
    return (widget.viewportWidth * ratio).clamp(30.0, widget.viewportWidth);
  }
  
  double get _thumbPosition {
    if (_maxScrollExtent <= 0) return 0;
    final scrollOffset = widget.controller.hasClients ? widget.controller.offset : 0;
    final scrollRatio = scrollOffset / _maxScrollExtent;
    final trackWidth = widget.viewportWidth - _thumbWidth;
    return scrollRatio * trackWidth;
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
    _dragStartScrollOffset = widget.controller.hasClients ? widget.controller.offset : 0;
    _dragStartLocalX = details.localPosition.dx;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || !widget.controller.hasClients) return;
    
    final deltaX = details.localPosition.dx - _dragStartLocalX;
    final trackWidth = widget.viewportWidth - _thumbWidth;
    if (trackWidth <= 0) return;
    
    final scrollDelta = (deltaX / trackWidth) * _maxScrollExtent;
    final newOffset = (_dragStartScrollOffset + scrollDelta).clamp(0.0, _maxScrollExtent);
    widget.controller.jumpTo(newOffset);
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.controller.hasClients) return;
    
    final trackWidth = widget.viewportWidth - _thumbWidth;
    if (trackWidth <= 0) return;
    
    final clickRatio = (details.localPosition.dx - _thumbWidth / 2) / trackWidth;
    final newOffset = (clickRatio * _maxScrollExtent).clamp(0.0, _maxScrollExtent);
    widget.controller.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contentWidth <= widget.viewportWidth) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.viewportWidth, 14),
            painter: _HorizontalScrollbarPainter(
              thumbPosition: _thumbPosition,
              thumbWidth: _thumbWidth,
              trackColor: Colors.grey.shade800.withOpacity(0.3),
              thumbColor: _isDragging ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          );
        },
      ),
    );
  }
}

class _HorizontalScrollbarPainter extends CustomPainter {
  final double thumbPosition;
  final double thumbWidth;
  final Color trackColor;
  final Color thumbColor;

  _HorizontalScrollbarPainter({
    required this.thumbPosition,
    required this.thumbWidth,
    required this.trackColor,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = trackColor;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 2, size.width, size.height - 4),
      const Radius.circular(5),
    );
    canvas.drawRRect(trackRect, trackPaint);
    
    final thumbPaint = Paint()..color = thumbColor;
    final thumbRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(thumbPosition, 2, thumbWidth, size.height - 4),
      const Radius.circular(5),
    );
    canvas.drawRRect(thumbRect, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _HorizontalScrollbarPainter oldDelegate) {
    return oldDelegate.thumbPosition != thumbPosition ||
           oldDelegate.thumbWidth != thumbWidth ||
           oldDelegate.thumbColor != thumbColor;
  }
}

/// Custom vertical scrollbar that doesn't require a ScrollView child.
class _CustomVerticalScrollbar extends StatefulWidget {
  final ScrollController controller;
  final double contentHeight;
  final double viewportHeight;

  const _CustomVerticalScrollbar({
    required this.controller,
    required this.contentHeight,
    required this.viewportHeight,
  });

  @override
  State<_CustomVerticalScrollbar> createState() => _CustomVerticalScrollbarState();
}

class _CustomVerticalScrollbarState extends State<_CustomVerticalScrollbar> {
  bool _isDragging = false;
  double _dragStartScrollOffset = 0;
  double _dragStartLocalY = 0;

  double get _maxScrollExtent => (widget.contentHeight - widget.viewportHeight).clamp(0, double.infinity);
  
  double get _thumbHeight {
    if (widget.contentHeight <= widget.viewportHeight) return widget.viewportHeight;
    final ratio = widget.viewportHeight / widget.contentHeight;
    return (widget.viewportHeight * ratio).clamp(30.0, widget.viewportHeight);
  }
  
  double get _thumbPosition {
    if (_maxScrollExtent <= 0) return 0;
    final scrollOffset = widget.controller.hasClients ? widget.controller.offset : 0;
    final scrollRatio = scrollOffset / _maxScrollExtent;
    final trackHeight = widget.viewportHeight - _thumbHeight;
    return scrollRatio * trackHeight;
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
    _dragStartScrollOffset = widget.controller.hasClients ? widget.controller.offset : 0;
    _dragStartLocalY = details.localPosition.dy;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || !widget.controller.hasClients) return;
    
    final deltaY = details.localPosition.dy - _dragStartLocalY;
    final trackHeight = widget.viewportHeight - _thumbHeight;
    if (trackHeight <= 0) return;
    
    final scrollDelta = (deltaY / trackHeight) * _maxScrollExtent;
    final newOffset = (_dragStartScrollOffset + scrollDelta).clamp(0.0, _maxScrollExtent);
    widget.controller.jumpTo(newOffset);
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.controller.hasClients) return;
    
    final trackHeight = widget.viewportHeight - _thumbHeight;
    if (trackHeight <= 0) return;
    
    final clickRatio = (details.localPosition.dy - _thumbHeight / 2) / trackHeight;
    final newOffset = (clickRatio * _maxScrollExtent).clamp(0.0, _maxScrollExtent);
    widget.controller.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contentHeight <= widget.viewportHeight) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(12, widget.viewportHeight),
            painter: _VerticalScrollbarPainter(
              thumbPosition: _thumbPosition,
              thumbHeight: _thumbHeight,
              trackColor: Colors.grey.shade800.withOpacity(0.3),
              thumbColor: _isDragging ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          );
        },
      ),
    );
  }
}

class _VerticalScrollbarPainter extends CustomPainter {
  final double thumbPosition;
  final double thumbHeight;
  final Color trackColor;
  final Color thumbColor;

  _VerticalScrollbarPainter({
    required this.thumbPosition,
    required this.thumbHeight,
    required this.trackColor,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = trackColor;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 0, size.width - 4, size.height),
      const Radius.circular(5),
    );
    canvas.drawRRect(trackRect, trackPaint);
    
    final thumbPaint = Paint()..color = thumbColor;
    final thumbRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, thumbPosition, size.width - 4, thumbHeight),
      const Radius.circular(5),
    );
    canvas.drawRRect(thumbRect, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _VerticalScrollbarPainter oldDelegate) {
    return oldDelegate.thumbPosition != thumbPosition ||
           oldDelegate.thumbHeight != thumbHeight ||
           oldDelegate.thumbColor != thumbColor;
  }
}




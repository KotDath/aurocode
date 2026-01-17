import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../application/editor_notifier.dart';
import '../application/editor_state.dart';
import '../domain/entities/editor_document.dart';
import '../infrastructure/syntax_highlighter.dart';

// Providers
final syntaxHighlighterProvider = Provider<SyntaxHighlighterService>((ref) {
  return SyntaxHighlighterService();
});

final editorProvider =
    StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  final fileRepository = ref.watch(fileSystemRepositoryProvider);
  return EditorNotifier(fileRepository);
});

class EditorTabsWidget extends ConsumerWidget {
  const EditorTabsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider);

    if (state.openDocuments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: state.openDocuments.length,
        itemBuilder: (context, index) {
          final document = state.openDocuments[index];
          final isActive = document.path == state.activeDocument?.path;

          return _buildTab(context, ref, document, isActive);
        },
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    WidgetRef ref,
    EditorDocument document,
    bool isActive,
  ) {
    return InkWell(
      onTap: () {
        ref.read(editorProvider.notifier).setActiveDocument(document);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E1E1E) : Colors.transparent,
          border: isActive
              ? const Border(
                  top: BorderSide(color: Colors.blue, width: 2),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              document.isDirty ? '● ${document.filename}' : document.filename,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? Colors.white : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                ref.read(editorProvider.notifier).closeDocument(document);
              },
              child: Icon(
                Icons.close,
                size: 16,
                color: isActive ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CodeEditorWidget extends ConsumerStatefulWidget {
  const CodeEditorWidget({super.key});

  @override
  ConsumerState<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends ConsumerState<CodeEditorWidget> {
  final ScrollController _lineNumberScrollController = ScrollController();
  final ScrollController _codeScrollController = ScrollController();
  TextEditingController? _textController;
  String? _currentPath;

  @override
  void initState() {
    super.initState();
    _codeScrollController.addListener(_syncLineNumbers);
  }

  void _syncLineNumbers() {
    if (_lineNumberScrollController.hasClients) {
      _lineNumberScrollController.jumpTo(_codeScrollController.offset);
    }
  }

  @override
  void dispose() {
    _codeScrollController.removeListener(_syncLineNumbers);
    _lineNumberScrollController.dispose();
    _codeScrollController.dispose();
    _textController?.dispose();
    super.dispose();
  }

  void _saveCurrentFile() {
    final document = ref.read(editorProvider).activeDocument;
    if (document != null && document.isDirty) {
      ref.read(editorProvider.notifier).saveDocument(document);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProvider);
    final document = state.activeDocument;

    if (document == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No file open',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Select a file from the explorer',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Update text controller when document changes
    if (_currentPath != document.path) {
      _currentPath = document.path;
      _textController?.dispose();
      final highlighter = ref.read(syntaxHighlighterProvider);
      _textController = CodeController(
        text: document.content,
        language: document.language,
        syntaxHighlighter: highlighter,
      );
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyS &&
            HardwareKeyboard.instance.isControlPressed) {
          _saveCurrentFile();
        }
      },
      child: Container(
        color: const Color(0xFF1E1E1E),
        child: Column(
          children: [
            _buildBreadcrumbs(context, document),
            Expanded(
              child: _buildEditor(context, document),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, EditorDocument document) {
    final parts = document.path.split('/');
    final displayParts = parts.length > 4 ? parts.sublist(parts.length - 4) : parts;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            displayParts.join(' / '),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context, EditorDocument document) {
    final lines = document.content.split('\n');
    const textStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 14,
      height: 1.5,
    );
    const strutStyle = StrutStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 14,
      height: 1.5,
      forceStrutHeight: true,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line numbers - synced with code scroll, no scrollbar
        SizedBox(
          width: 50,
          child: IgnorePointer(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView.builder(
                controller: _lineNumberScrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: lines.length,
                itemBuilder: (context, index) => SizedBox(
                  height: 21,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${index + 1}',
                        style: textStyle.copyWith(color: Colors.grey.shade600),
                        strutStyle: strutStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Code content - editable, with single scrollbar
        Expanded(
          child: Scrollbar(
            controller: _codeScrollController,
            thumbVisibility: true,
            child: ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              child: TextField(
                controller: _textController,
                scrollController: _codeScrollController,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                style: textStyle.copyWith(color: Colors.white),
                strutStyle: strutStyle,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(8),
                ),
                onChanged: (value) {
                  ref.read(editorProvider.notifier).updateContent(document.path, value);
                  setState(() {}); // Rebuild line numbers
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EditorArea extends ConsumerWidget {
  const EditorArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      children: [
        EditorTabsWidget(),
        Expanded(child: CodeEditorWidget()),
      ],
    );
  }
}


class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class CodeController extends TextEditingController {
  final String language;
  final SyntaxHighlighterService syntaxHighlighter;

  CodeController({
    super.text,
    required this.language,
    required this.syntaxHighlighter,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final highlighted = syntaxHighlighter.highlight(text, language);
    if (highlighted != null) {
      return TextSpan(
        style: style,
        children: [highlighted],
      );
    }
    return super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
  }
}

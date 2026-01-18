import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../core/di/providers.dart';
import '../application/editor_notifier.dart';
import '../application/editor_state.dart';
import '../application/language_service.dart';
import '../application/rope_editor_controller.dart';
import '../domain/entities/editor_document.dart';
import '../domain/entities/rope.dart';
import '../domain/entities/rope_change.dart';
import 'rope_editor_widget.dart';

// Providers
final editorProvider =
    StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  final fileRepository = ref.watch(fileSystemRepositoryProvider);
  final languageService = ref.watch(languageServiceProvider);
  return EditorNotifier(fileRepository, languageService);
});

class EditorTabsWidget extends ConsumerStatefulWidget {
  const EditorTabsWidget({super.key});

  @override
  ConsumerState<EditorTabsWidget> createState() => _EditorTabsWidgetState();
}

class _EditorTabsWidgetState extends ConsumerState<EditorTabsWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final offset = _scrollController.offset + event.scrollDelta.dy;
            _scrollController.jumpTo(
              offset.clamp(0.0, _scrollController.position.maxScrollExtent),
            );
          }
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: state.openDocuments.length,
            itemBuilder: (context, index) {
              final document = state.openDocuments[index];
              final isActive = document.path == state.activeDocument?.path;

              return _buildTab(context, ref, document, isActive);
            },
          ),
        ),
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
  RopeEditorController? _ropeController;
  String? _currentPath;
  bool _lspInitialized = false;

  @override
  void dispose() {
    _closeCurrentDocument();
    _ropeController?.dispose();
    super.dispose();
  }

  Future<void> _openDocumentInLsp(EditorDocument document) async {
    final provider = ref.read(highlightProviderProvider);
    try {
      await provider.documentOpened(document.path, document.content, document.language);
      if (mounted) {
        setState(() {
          _lspInitialized = true;
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  void _closeCurrentDocument() {
    if (_currentPath != null && _lspInitialized) {
      final provider = ref.read(highlightProviderProvider);
      provider.documentClosed(_currentPath!);
    }
  }

  Timer? _debounceTimer;

  void _onContentChanged(Rope rope, RopeChange? change) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    // For incremental updates, we don't need to debounce as aggressively 
    // because we aren't doing the expensive O(N) toString().
    
    // However, we still update the global state (which might need toString if it's dumb).
    // Let's optimize: Only notify LSP incrementally immediately?
    // But we also need to update editorProvider state... 
    // If editorProvider needs full string, we are still stuck.
    // Let's assume editorProvider can wait (debounce 500ms).
    // But LSP should be fast for responsiveness (diagnostics, etc).
    
    // If we have a delta, send it to LSP immediately!
    if (change != null && _lspInitialized) {
      final document = ref.read(editorProvider).activeDocument;
      if (document != null && !document.isReadOnly) {
        final provider = ref.read(highlightProviderProvider);
        provider.documentChangedWithRange(document.path, rope, change);
      }
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      final document = ref.read(editorProvider).activeDocument;
      if (document == null || document.isReadOnly) return;
      
      // Update global state (still potentially expensive, but debounced)
      final content = rope.toString();
      ref.read(editorProvider.notifier).updateContent(document.path, content);
      
      // If we didn't have a change object (e.g. undo/redo might not pass it correctly yet?), 
      // or if we just want to ensure consistency, we could full-sync here too?
      // But we handled LSP above.
      
      // Note: If 'change' was null (e.g. from setRope/undo without delta), we might need to full sync LSP here.
      if (change == null && _lspInitialized) {
        final provider = ref.read(highlightProviderProvider);
        provider.documentChanged(document.path, content);
      }
    });
  }

  void _saveCurrentFile() {
    final document = ref.read(editorProvider).activeDocument;
    if (document != null && document.isDirty) {
      // Sync content from controller before saving
      if (_ropeController != null) {
        ref.read(editorProvider.notifier).updateContent(
          document.path, 
          _ropeController!.rope.toString(),
        );
      }
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

    // Update controller when document changes
    if (_currentPath != document.path) {
      _closeCurrentDocument();
      _currentPath = document.path;
      _lspInitialized = false;
      _ropeController?.dispose();
      _ropeController = RopeEditorController(
        initialText: document.content,
        readOnly: document.isReadOnly,
        onChanged: _onContentChanged,
      );
      _openDocumentInLsp(document);
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
          if (document.isReadOnly) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: const Text(
                'READ ONLY',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context, EditorDocument document) {
    if (_ropeController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final highlightProvider = ref.watch(highlightProviderProvider);
    
    return RopeEditorWidget(
      controller: _ropeController!,
      highlightProvider: highlightProvider,
      language: document.language,
      filePath: document.path,
      textStyle: const TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 14,
        height: 1.5,
        color: Colors.white,
      ),
      lspReady: _lspInitialized,
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

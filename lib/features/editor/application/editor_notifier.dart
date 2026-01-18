import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../file_tree/domain/repositories/file_system_repository.dart';
import '../application/editor_state.dart';
import '../domain/entities/editor_document.dart';
import 'language_service.dart';

class EditorNotifier extends StateNotifier<EditorState> {
  final FileSystemRepository _fileRepository;
  final LanguageService _languageService;

  EditorNotifier(this._fileRepository, this._languageService) : super(const EditorState());

  Future<void> openFile(String path) async {
    // Check if already open
    final existing = state.openDocuments.where((d) => d.path == path);
    if (existing.isNotEmpty) {
      state = state.copyWith(activeDocument: existing.first);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final content = await _fileRepository.readFile(path);
      final language = _languageService.detectLanguage(path);

      final document = EditorDocument(
        path: path,
        content: content,
        language: language,
      );

      state = EditorState(
        openDocuments: [...state.openDocuments, document],
        activeDocument: document,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to open file: $e',
      );
    }
  }

  void setActiveDocument(EditorDocument document) {
    state = state.copyWith(activeDocument: document);
  }

  void closeDocument(EditorDocument document) {
    final updated =
        state.openDocuments.where((doc) => doc.path != document.path).toList();

    EditorDocument? newActive;
    if (state.activeDocument?.path == document.path && updated.isNotEmpty) {
      final oldIndex = state.openDocuments
          .indexWhere((d) => d.path == document.path);
      newActive =
          oldIndex > 0 ? updated[oldIndex - 1] : updated.first;
    } else if (updated.isEmpty) {
      state = EditorState(openDocuments: updated);
      return;
    } else {
      newActive = state.activeDocument;
    }

    state = EditorState(
      openDocuments: updated,
      activeDocument: newActive,
    );
  }

  void updateContent(String path, String content) {
    final updated = state.openDocuments.map((doc) {
      if (doc.path == path) {
        return doc.copyWith(content: content, isDirty: true);
      }
      return doc;
    }).toList();

    final active = state.activeDocument?.path == path
        ? updated.firstWhere((d) => d.path == path)
        : state.activeDocument;

    state = EditorState(
      openDocuments: updated,
      activeDocument: active,
    );
  }

  Future<void> saveDocument(EditorDocument document) async {
    try {
      await _fileRepository.writeFile(document.path, document.content);

      final updated = state.openDocuments.map((doc) {
        if (doc.path == document.path) {
          return doc.copyWith(isDirty: false);
        }
        return doc;
      }).toList();

      state = EditorState(
        openDocuments: updated,
        activeDocument: state.activeDocument?.path == document.path
            ? updated.firstWhere((d) => d.path == document.path)
            : state.activeDocument,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to save: $e');
    }
  }

  Future<void> saveAsDocument(EditorDocument document, String newPath) async {
    try {
      await _fileRepository.writeFile(newPath, document.content);
      
      final newDoc = EditorDocument(
        path: newPath,
        content: document.content,
        language: EditorDocument.detectLanguage(newPath),
        isDirty: false,
      );

      // Replace old document with new one
      final updated = state.openDocuments.map((doc) {
        if (doc.path == document.path) {
          return newDoc;
        }
        return doc;
      }).toList();

      state = EditorState(
        openDocuments: updated,
        activeDocument: state.activeDocument?.path == document.path
            ? newDoc
            : state.activeDocument,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to save: $e');
    }
  }
}

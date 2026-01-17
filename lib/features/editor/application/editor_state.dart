import '../domain/entities/editor_document.dart';

class EditorState {
  final List<EditorDocument> openDocuments;
  final EditorDocument? activeDocument;
  final bool isLoading;
  final String? error;

  const EditorState({
    this.openDocuments = const [],
    this.activeDocument,
    this.isLoading = false,
    this.error,
  });

  EditorState copyWith({
    List<EditorDocument>? openDocuments,
    EditorDocument? activeDocument,
    bool? isLoading,
    String? error,
    bool clearActive = false,
  }) {
    return EditorState(
      openDocuments: openDocuments ?? this.openDocuments,
      activeDocument:
          clearActive ? null : (activeDocument ?? this.activeDocument),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

import '../domain/entities/file_node.dart';

class FileTreeState {
  final String? projectPath;
  final List<FileNode> rootNodes;
  final bool isLoading;
  final String? error;
  final String? selectedPath;

  const FileTreeState({
    this.projectPath,
    this.rootNodes = const [],
    this.isLoading = false,
    this.error,
    this.selectedPath,
  });

  FileTreeState copyWith({
    String? projectPath,
    List<FileNode>? rootNodes,
    bool? isLoading,
    String? error,
    String? selectedPath,
  }) {
    return FileTreeState(
      projectPath: projectPath ?? this.projectPath,
      rootNodes: rootNodes ?? this.rootNodes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedPath: selectedPath ?? this.selectedPath,
    );
  }

  /// Flatten the tree for ListView rendering
  List<FileNode> get flattenedNodes {
    final result = <FileNode>[];
    void flatten(List<FileNode> nodes) {
      for (final node in nodes) {
        result.add(node);
        if (node.isDirectory && node.isExpanded) {
          flatten(node.children);
        }
      }
    }
    flatten(rootNodes);
    return result;
  }
}

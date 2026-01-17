import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/file_tree_state.dart';
import '../domain/entities/file_node.dart';
import '../domain/repositories/file_system_repository.dart';

class FileTreeNotifier extends StateNotifier<FileTreeState> {
  final FileSystemRepository _repository;

  FileTreeNotifier(this._repository) : super(const FileTreeState());

  Future<void> loadProject(String path) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final nodes = await _repository.loadDirectory(path, level: 0);
      state = FileTreeState(
        projectPath: path,
        rootNodes: nodes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void toggleNode(FileNode node) {
    if (!node.isDirectory) return;

    final updatedNodes = _toggleNodeInList(state.rootNodes, node.path);
    state = state.copyWith(rootNodes: updatedNodes);
  }

  void selectNode(FileNode node) {
    state = state.copyWith(selectedPath: node.path);
  }

  List<FileNode> _toggleNodeInList(List<FileNode> nodes, String targetPath) {
    return nodes.map((node) {
      if (node.path == targetPath && node.isDirectory) {
        return node.copyWith(isExpanded: !node.isExpanded);
      }
      if (node.children.isNotEmpty) {
        return node.copyWith(
          children: _toggleNodeInList(node.children, targetPath),
        );
      }
      return node;
    }).toList();
  }
}

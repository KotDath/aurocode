import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../application/file_tree_notifier.dart';
import '../application/file_tree_state.dart';
import '../domain/entities/file_node.dart';

// Providers
final fileTreeProvider =
    StateNotifierProvider<FileTreeNotifier, FileTreeState>((ref) {
  final repository = ref.watch(fileSystemRepositoryProvider);
  return FileTreeNotifier(repository);
});

// Callback for when a file is selected
typedef OnFileSelected = void Function(String path);

class FileTreeWidget extends ConsumerStatefulWidget {
  final OnFileSelected? onFileSelected;
  final String? rootPath;

  const FileTreeWidget({super.key, this.onFileSelected, this.rootPath});

  @override
  ConsumerState<FileTreeWidget> createState() => _FileTreeWidgetState();
}

class _FileTreeWidgetState extends ConsumerState<FileTreeWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProject();
    });
  }

  @override
  void didUpdateWidget(FileTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPath != widget.rootPath && widget.rootPath != null) {
      // Delay state modification to after the build phase
      Future(() {
        ref.read(fileTreeProvider.notifier).loadProject(widget.rootPath!);
      });
    }
  }

  void _loadProject() {
    final path = widget.rootPath ?? '/home/kotdath/omp/personal/rust/aurocode';
    ref.read(fileTreeProvider.notifier).loadProject(path);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fileTreeProvider);

    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          _buildHeader(context, state.projectPath),
          const Divider(height: 1),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.flattenedNodes.length,
                        itemBuilder: (context, index) {
                          return _buildNode(
                            context,
                            state.flattenedNodes[index],
                            state.selectedPath,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? projectPath) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(Icons.folder_open, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              projectPath?.split('/').last ?? 'No Project',
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              if (projectPath != null) {
                ref.read(fileTreeProvider.notifier).loadProject(projectPath);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNode(
    BuildContext context,
    FileNode node,
    String? selectedPath,
  ) {
    return _HoverableFileNode(
      node: node,
      isSelected: node.path == selectedPath,
      onTap: () {
        if (node.isDirectory) {
          ref.read(fileTreeProvider.notifier).toggleNode(node);
        } else {
          ref.read(fileTreeProvider.notifier).selectNode(node);
          widget.onFileSelected?.call(node.path);
        }
      },
    );
  }
}

class _HoverableFileNode extends StatefulWidget {
  final FileNode node;
  final bool isSelected;
  final VoidCallback onTap;

  const _HoverableFileNode({
    required this.node,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_HoverableFileNode> createState() => _HoverableFileNodeState();
}

class _HoverableFileNodeState extends State<_HoverableFileNode> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.node.level * 16.0 + 8.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.only(
            left: indent,
            right: 8,
            top: 4,
            bottom: 4,
          ),
          color: widget.isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : _isHovered
                  ? Colors.white.withValues(alpha: 0.05)
                  : null,
          child: Row(
            children: [
              if (widget.node.isDirectory)
                Icon(
                  widget.node.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 16,
                  color: Colors.grey,
                )
              else
                const SizedBox(width: 16),
              const SizedBox(width: 4),
              Icon(
                widget.node.icon,
                size: 16,
                color: widget.node.iconColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.node.name,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

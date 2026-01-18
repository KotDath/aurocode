import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../../../core/services/file_dialog_service.dart';
import '../../../core/shared/widgets/resizable_split_view.dart';
import '../../ai_panel/presentation/ai_panel_widget.dart';
import '../../editor/presentation/code_editor_widget.dart';
import '../../file_tree/presentation/file_tree_widget.dart';
import '../../runner/presentation/run_button_widget.dart';
import '../../terminal/presentation/native_terminal_widget.dart';

class IdeLayout extends ConsumerStatefulWidget {
  const IdeLayout({super.key});

  @override
  ConsumerState<IdeLayout> createState() => _IdeLayoutState();
}

class _IdeLayoutState extends ConsumerState<IdeLayout> {
  bool _aiPanelVisible = false;
  String _projectPath = '/home/kotdath/omp/personal/rust/aurocode';
  final _fileDialogService = FileDialogService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildMenuBar(context),
          Expanded(
            child: ResizableSplitView(
              direction: SplitDirection.horizontal,
              initialRatio: 0.2,
              minRatio: 0.1,
              maxRatio: 0.4,
              first: _buildFileTree(),
              second: _buildCenterArea(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArea(BuildContext context) {
    if (_aiPanelVisible) {
      return ResizableSplitView(
        direction: SplitDirection.horizontal,
        initialRatio: 0.7,
        minRatio: 0.4,
        maxRatio: 0.9,
        first: _buildMainArea(context),
        second: _buildAiPanel(context),
      );
    }
    return _buildMainArea(context);
  }

  Widget _buildMenuBar(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        children: [
          // Layer 1: Window Dragging & Background
          Positioned.fill(
            child: GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Container(color: const Color(0xFF252526)),
            ),
          ),
          // Layer 2: Interactive Menu Elements
          Row(
            children: [
              const SizedBox(width: 8),
              // App icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const Icon(Icons.code, size: 16, color: Colors.blue),
              ),
              // Menu items (Zed/VSCode style)
              _buildMenuTextButton(context, 'File', [
                _MenuItem('New File', 'Ctrl+N'),
                _MenuItem('New Window', 'Ctrl+Shift+N'),
                _MenuSeparator(),
                _MenuItem('Open File...', 'Ctrl+O'),
                _MenuItem('Open Folder...', 'Ctrl+K Ctrl+O'),
                _MenuSeparator(),
                _MenuItem('Save', 'Ctrl+S'),
                _MenuItem('Save As...', 'Ctrl+Shift+S'),
                _MenuSeparator(),
                _MenuItem('Close Editor', 'Ctrl+W'),
              ], _handleFileMenuAction),
              _buildMenuTextButton(context, 'Edit', [
                _MenuItem('Undo', 'Ctrl+Z'),
                _MenuItem('Redo', 'Ctrl+Shift+Z'),
                _MenuSeparator(),
                _MenuItem('Cut', 'Ctrl+X'),
                _MenuItem('Copy', 'Ctrl+C'),
                _MenuItem('Paste', 'Ctrl+V'),
                _MenuSeparator(),
                _MenuItem('Find', 'Ctrl+F'),
                _MenuItem('Replace', 'Ctrl+H'),
              ]),
              _buildMenuTextButton(context, 'View', [
                _MenuItem('Command Palette', 'Ctrl+Shift+P'),
                _MenuSeparator(),
                _MenuItem('Explorer', 'Ctrl+Shift+E'),
                _MenuItem('Terminal', 'Ctrl+`'),
                _MenuItem('AI Assistant', 'Ctrl+Shift+A'),
              ]),
              _buildMenuTextButton(context, 'Go', [
                _MenuItem('Go to File...', 'Ctrl+P'),
                _MenuItem('Go to Symbol...', 'Ctrl+Shift+O'),
                _MenuItem('Go to Line...', 'Ctrl+G'),
                _MenuSeparator(),
                _MenuItem('Go to Definition', 'F12'),
                _MenuItem('Go to References', 'Shift+F12'),
              ]),
              const SizedBox(width: 8),
              // Run button
              RunButtonWidget(projectPath: _projectPath),
              const Spacer(),
              // Window title centered
              const IgnorePointer(
                child: Text(
                  'Aurocode',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const Spacer(),
              // AI panel toggle
              _buildTitleBarIconButton(
                icon: Icons.smart_toy,
                tooltip: 'AI Assistant',
                isActive: _aiPanelVisible,
                onPressed: () => setState(() => _aiPanelVisible = !_aiPanelVisible),
              ),
              const SizedBox(width: 8),
              // Window controls
              _buildWindowControl(Icons.remove, 'Minimize', () => windowManager.minimize()),
              _buildWindowControl(Icons.crop_square_outlined, 'Maximize', () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              }),
              _buildWindowControl(Icons.close, 'Close', () => windowManager.close(), isClose: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTextButton(BuildContext context, String label, List<_MenuItemBase> items, [void Function(String)? onSelected]) {
    return _HoverableMenuButton(label: label, items: items, onSelected: onSelected);
  }

  Future<void> _handleFileMenuAction(String action) async {
    switch (action) {
      case 'Open File...':
        final path = await _fileDialogService.pickFile();
        if (path != null) {
          ref.read(editorProvider.notifier).openFile(path);
        }
        break;
      case 'Open Folder...':
        final path = await _fileDialogService.pickDirectory();
        if (path != null) {
          setState(() => _projectPath = path);
        }
        break;
      case 'Save':
        final doc = ref.read(editorProvider).activeDocument;
        if (doc != null) {
          ref.read(editorProvider.notifier).saveDocument(doc);
        }
        break;
      case 'Save As...':
        final doc = ref.read(editorProvider).activeDocument;
        if (doc != null) {
          final newPath = await _fileDialogService.pickSaveLocation(
            fileName: p.basename(doc.path),
          );
          if (newPath != null) {
            ref.read(editorProvider.notifier).saveAsDocument(doc, newPath);
          }
        }
        break;
      case 'Close Editor':
        final doc = ref.read(editorProvider).activeDocument;
        if (doc != null) {
          ref.read(editorProvider.notifier).closeDocument(doc);
        }
        break;
    }
  }

  Widget _buildTitleBarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 28,
          height: 20,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.withValues(alpha: 0.2) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 14, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  Widget _buildWindowControl(IconData icon, String tooltip, VoidCallback onPressed, {bool isClose = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 46,
          height: 32,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 14, color: isClose ? Colors.grey.shade300 : Colors.grey.shade500),
          ),
        ),
      ),
    );
  }

  Widget _buildFileTree() {
    return FileTreeWidget(
      rootPath: _projectPath,
      onFileSelected: (path) {
        ref.read(editorProvider.notifier).openFile(path);
      },
    );
  }

  Widget _buildMainArea(BuildContext context) {
    return ResizableSplitView(
      direction: SplitDirection.vertical,
      initialRatio: 0.75,
      minRatio: 0.3,
      maxRatio: 0.95,
      first: _buildEditor(),
      second: const NativeTerminalWidget(),
    );
  }

  Widget _buildEditor() {
    return const EditorArea();
  }

  Widget _buildAiPanel(BuildContext context) {
    return const AiPanelWidget();
  }
}

// Helper classes for menu items
abstract class _MenuItemBase {}

class _MenuItem extends _MenuItemBase {
  final String label;
  final String shortcut;
  _MenuItem(this.label, this.shortcut);
}

class _MenuSeparator extends _MenuItemBase {}

class _HoverableMenuButton extends StatefulWidget {
  final String label;
  final List<_MenuItemBase> items;
  final void Function(String)? onSelected;

  const _HoverableMenuButton({required this.label, required this.items, this.onSelected});

  @override
  State<_HoverableMenuButton> createState() => _HoverableMenuButtonState();
}

class _HoverableMenuButtonState extends State<_HoverableMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: PopupMenuButton<String>(
        tooltip: '',
        offset: const Offset(0, 32),
        color: const Color(0xFF2D2D30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        popUpAnimationStyle: AnimationStyle.noAnimation,
        onSelected: widget.onSelected,
        itemBuilder: (context) {
          final List<PopupMenuEntry<String>> entries = [];
          for (final item in widget.items) {
            if (item is _MenuSeparator) {
              entries.add(const PopupMenuDivider(height: 1));
            } else if (item is _MenuItem) {
              entries.add(PopupMenuItem<String>(
                value: item.label,
                height: 28,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      item.shortcut,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ));
            }
          }
          return entries;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

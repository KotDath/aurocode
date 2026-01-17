import 'package:flutter/material.dart';

class FileNode {
  final String path;
  final String name;
  final bool isDirectory;
  final int level;
  final bool isExpanded;
  final List<FileNode> children;

  const FileNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.level = 0,
    this.isExpanded = false,
    this.children = const [],
  });

  IconData get icon {
    if (isDirectory) {
      return isExpanded ? Icons.folder_open : Icons.folder;
    }

    final ext = name.split('.').lastOrNull?.toLowerCase() ?? '';
    return switch (ext) {
      'dart' => Icons.flutter_dash,
      'yaml' || 'yml' => Icons.settings,
      'json' => Icons.data_object,
      'md' => Icons.description,
      'png' || 'jpg' || 'jpeg' || 'gif' => Icons.image,
      'rs' => Icons.code,
      'toml' => Icons.settings,
      _ => Icons.insert_drive_file,
    };
  }

  Color get iconColor {
    if (isDirectory) return Colors.blue.shade400;

    final ext = name.split('.').lastOrNull?.toLowerCase() ?? '';
    return switch (ext) {
      'dart' => Colors.blue.shade300,
      'yaml' || 'yml' || 'json' => Colors.orange.shade300,
      'md' => Colors.grey.shade400,
      'rs' => Colors.orange.shade400,
      _ => Colors.grey.shade400,
    };
  }

  FileNode copyWith({
    String? path,
    String? name,
    bool? isDirectory,
    int? level,
    bool? isExpanded,
    List<FileNode>? children,
  }) {
    return FileNode(
      path: path ?? this.path,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      level: level ?? this.level,
      isExpanded: isExpanded ?? this.isExpanded,
      children: children ?? this.children,
    );
  }
}

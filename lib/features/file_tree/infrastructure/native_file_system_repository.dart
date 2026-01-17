import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/entities/file_node.dart';
import '../domain/repositories/file_system_repository.dart';

class NativeFileSystemRepository implements FileSystemRepository {
  @override
  Future<List<FileNode>> loadDirectory(String path, {int level = 0}) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      throw Exception('Directory does not exist: $path');
    }

    final entities = await dir.list().toList();
    final nodes = <FileNode>[];

    for (final entity in entities) {
      final name = p.basename(entity.path);

      // Skip hidden files/folders
      if (name.startsWith('.')) continue;
      // Skip build directories
      if (name == 'build' || name == 'target' || name == 'node_modules') {
        continue;
      }

      if (entity is Directory) {
        // Eagerly load children for directories
        final children = await loadDirectory(entity.path, level: level + 1);
        nodes.add(FileNode(
          path: entity.path,
          name: name,
          isDirectory: true,
          level: level,
          children: children,
        ));
      } else if (entity is File) {
        nodes.add(FileNode(
          path: entity.path,
          name: name,
          isDirectory: false,
          level: level,
        ));
      }
    }

    // Sort: folders first, then files, both alphabetically
    nodes.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return nodes;
  }

  @override
  Future<bool> exists(String path) async {
    return await File(path).exists() || await Directory(path).exists();
  }

  @override
  Future<String> readFile(String path) async {
    final file = File(path);
    return await file.readAsString();
  }

  @override
  Future<void> writeFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }
}

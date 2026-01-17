import '../entities/file_node.dart';

abstract class FileSystemRepository {
  Future<List<FileNode>> loadDirectory(String path, {int level = 0});
  Future<bool> exists(String path);
  Future<String> readFile(String path);
  Future<void> writeFile(String path, String content);
}

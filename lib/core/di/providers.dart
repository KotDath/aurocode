import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/file_tree/domain/repositories/file_system_repository.dart';
import '../../features/file_tree/infrastructure/native_file_system_repository.dart';

final fileSystemRepositoryProvider = Provider<FileSystemRepository>((ref) {
  return NativeFileSystemRepository();
});

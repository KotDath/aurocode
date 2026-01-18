import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class LanguageService {
  // Default mappings
  final Map<String, String> _extensionMap = {
    'dart': 'dart',
    'yaml': 'yaml',
    'yml': 'yaml',
    'json': 'json',
    'md': 'markdown',
    'py': 'python',
    'rs': 'rust',
    'js': 'javascript',
    'ts': 'typescript',
    'toml': 'toml',
    'html': 'html',
    'css': 'css',
    'cpp': 'cpp',
    'cc': 'cpp',
    'cxx': 'cpp',
    'c': 'cpp',
    'h': 'cpp',
    'hpp': 'cpp',
    'cmake': 'cmake',
    'txt': 'text', // Changed from cmake to text
    'go': 'go',
    'sh': 'bash',
    'bash': 'bash',
    'sql': 'sql',
    'java': 'java',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'swift': 'swift',
    'gradle': 'gradle',
    'xml': 'xml',
  };

  void registerMapping(String extension, String languageId) {
    if (extension.startsWith('.')) {
      extension = extension.substring(1);
    }
    _extensionMap[extension.toLowerCase()] = languageId;
  }

  String detectLanguage(String path) {
    final filename = p.basename(path).toLowerCase();
    
    // Special filenames
    if (filename == 'cmakelists.txt') return 'cmake';
    if (filename == 'makefile') return 'makefile';
    if (filename == 'dockerfile') return 'dockerfile';
    
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty) return 'text';
    
    final extension = ext.substring(1); // Remove dot
    return _extensionMap[extension] ?? 'text';
  }
}

final languageServiceProvider = Provider<LanguageService>((ref) {
  return LanguageService();
});

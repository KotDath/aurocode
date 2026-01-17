class EditorDocument {
  final String path;
  final String content;
  final String language;
  final bool isDirty;

  const EditorDocument({
    required this.path,
    required this.content,
    required this.language,
    this.isDirty = false,
  });

  String get filename => path.split('/').last;

  EditorDocument copyWith({
    String? path,
    String? content,
    String? language,
    bool? isDirty,
  }) {
    return EditorDocument(
      path: path ?? this.path,
      content: content ?? this.content,
      language: language ?? this.language,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  static String detectLanguage(String path) {
    final ext = path.split('.').lastOrNull?.toLowerCase() ?? '';
    return switch (ext) {
      'dart' => 'dart',
      'yaml' || 'yml' => 'yaml',
      'json' => 'json',
      'md' => 'markdown',
      'py' => 'python',
      'rs' => 'rust',
      'js' => 'javascript',
      'ts' => 'typescript',
      'toml' => 'toml',
      'html' => 'html',
      'css' => 'css',
      'cpp' || 'cc' || 'cxx' || 'c' || 'h' || 'hpp' => 'cpp',
      'cmake' || 'txt' => 'cmake', // CMakeLists.txt
      'go' => 'go',
      'sh' || 'bash' => 'bash',
      'sql' => 'sql',
      'java' => 'java',
      'kt' || 'kts' => 'kotlin',
      'swift' => 'swift',
      'gradle' => 'gradle',
      'xml' => 'xml',
      _ => 'text',
    };
  }
}

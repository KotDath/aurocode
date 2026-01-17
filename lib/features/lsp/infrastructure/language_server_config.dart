/// Configuration for different language servers.
library;

/// Configuration for a language server.
class LanguageServerConfig {
  final String id;
  final String name;
  final String executable;
  final List<String> arguments;
  final List<String> fileExtensions;
  final Map<String, String> environment;

  const LanguageServerConfig({
    required this.id,
    required this.name,
    required this.executable,
    this.arguments = const [],
    required this.fileExtensions,
    this.environment = const {},
  });
}

/// Known language server configurations.
abstract final class LanguageServers {
  static const dart = LanguageServerConfig(
    id: 'dart',
    name: 'Dart Analysis Server',
    executable: 'dart',
    arguments: ['language-server', '--protocol=lsp'],
    fileExtensions: ['dart'],
  );

  static const rustAnalyzer = LanguageServerConfig(
    id: 'rust-analyzer',
    name: 'Rust Analyzer',
    executable: 'rust-analyzer',
    fileExtensions: ['rs'],
  );

  static const gopls = LanguageServerConfig(
    id: 'gopls',
    name: 'gopls',
    executable: 'gopls',
    fileExtensions: ['go'],
  );

  static const clangd = LanguageServerConfig(
    id: 'clangd',
    name: 'clangd',
    executable: 'clangd',
    fileExtensions: ['c', 'cpp', 'h', 'hpp', 'cc', 'cxx'],
  );

  static const typescript = LanguageServerConfig(
    id: 'typescript',
    name: 'TypeScript Language Server',
    executable: 'typescript-language-server',
    arguments: ['--stdio'],
    fileExtensions: ['ts', 'tsx', 'js', 'jsx'],
  );

  static const pyright = LanguageServerConfig(
    id: 'pyright',
    name: 'Pyright',
    executable: 'pyright-langserver',
    arguments: ['--stdio'],
    fileExtensions: ['py'],
  );

  static const all = [dart, rustAnalyzer, gopls, clangd, typescript, pyright];

  static LanguageServerConfig? forExtension(String extension) {
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    for (final config in all) {
      if (config.fileExtensions.contains(ext)) {
        return config;
      }
    }
    return null;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/editor/application/diagnostics_provider.dart';
import '../../features/editor/domain/highlight_provider.dart';
import '../../features/editor/infrastructure/composite_highlight_provider.dart';
import '../../features/editor/infrastructure/lsp_highlight_provider.dart';
import '../../features/editor/infrastructure/regex_highlight_provider.dart';
import '../../features/file_tree/domain/repositories/file_system_repository.dart';
import '../../features/file_tree/infrastructure/native_file_system_repository.dart';
import '../../features/lsp/application/lsp_service.dart';

final fileSystemRepositoryProvider = Provider<FileSystemRepository>((ref) {
  return NativeFileSystemRepository();
});

final lspServiceProvider = Provider<LspService>((ref) {
  final lspService = LspService();
  
  // Wire diagnostics: subscribe DiagnosticsNotifier to LspService.diagnostics stream
  final diagnosticsNotifier = ref.read(diagnosticsProvider.notifier);
  diagnosticsNotifier.subscribeToStream(lspService.diagnostics);
  
  ref.onDispose(() => lspService.dispose());
  return lspService;
});

final highlightProviderProvider = Provider<HighlightProvider>((ref) {
  final lspService = ref.watch(lspServiceProvider);
  final provider = CompositeHighlightProvider([
    LspHighlightProvider(lspService),
    RegexHighlightProvider(),
  ]);
  ref.onDispose(() => provider.dispose());
  return provider;
});

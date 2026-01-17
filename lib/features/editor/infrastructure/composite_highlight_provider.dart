/// Composite highlight provider that combines multiple providers.
///
/// Uses regex for immediate highlighting, then overlays LSP tokens when available.
library;

import '../domain/entities/highlight_token.dart';
import '../domain/highlight_provider.dart';

/// Combines multiple highlight providers.
///
/// Primary provider (usually regex) is used for immediate results.
/// Secondary providers (like LSP) provide enhanced highlighting asynchronously.
class CompositeHighlightProvider implements HighlightProvider {
  final List<HighlightProvider> _providers;

  CompositeHighlightProvider(this._providers);

  @override
  Future<List<HighlightToken>?> highlight(
    String code,
    String language, [
    String? filePath,
  ]) async {
    // Try each provider in order, return the first non-null result
    for (final provider in _providers) {
      final result = await provider.highlight(code, language, filePath);
      if (result != null && result.isNotEmpty) {
        return result;
      }
    }
    return null;
  }

  @override
  Future<void> documentOpened(
    String filePath,
    String content,
    String language,
  ) async {
    for (final provider in _providers) {
      await provider.documentOpened(filePath, content, language);
    }
  }

  @override
  Future<void> documentChanged(String filePath, String content) async {
    for (final provider in _providers) {
      await provider.documentChanged(filePath, content);
    }
  }

  @override
  Future<void> documentClosed(String filePath) async {
    for (final provider in _providers) {
      await provider.documentClosed(filePath);
    }
  }

  @override
  void dispose() {
    for (final provider in _providers) {
      provider.dispose();
    }
  }
}

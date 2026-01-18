/// Diagnostics service that listens to LSP diagnostics and provides them to the editor.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lsp/infrastructure/lsp_client.dart';
import '../domain/entities/diagnostic.dart';
import '../domain/entities/line_decoration.dart';

/// State for diagnostics across all files.
class DiagnosticsState {
  /// Map from file path to list of diagnostics.
  final Map<String, List<EditorDiagnostic>> diagnosticsByFile;

  const DiagnosticsState({this.diagnosticsByFile = const {}});

  DiagnosticsState copyWith({
    Map<String, List<EditorDiagnostic>>? diagnosticsByFile,
  }) {
    return DiagnosticsState(
      diagnosticsByFile: diagnosticsByFile ?? this.diagnosticsByFile,
    );
  }

  /// Get diagnostics for a specific file path.
  List<EditorDiagnostic> forFile(String filePath) {
    // Try to match by file URI or path
    final uri = Uri.file(filePath).toString();
    return diagnosticsByFile[uri] ?? diagnosticsByFile[filePath] ?? [];
  }
}

/// Notifier for managing diagnostics state.
class DiagnosticsNotifier extends StateNotifier<DiagnosticsState> {
  StreamSubscription<FileDiagnostics>? _subscription;

  DiagnosticsNotifier() : super(const DiagnosticsState());

  /// Subscribe to diagnostics from an LSP client.
  void subscribeToClient(LspClient client) {
    _subscription?.cancel();
    _subscription = client.diagnostics.listen(_onDiagnostics);
  }

  /// Subscribe to diagnostics stream (from LspService).
  void subscribeToStream(Stream<FileDiagnostics> stream) {
    _subscription?.cancel();
    _subscription = stream.listen(_onDiagnostics);
  }

  void _onDiagnostics(FileDiagnostics fileDiagnostics) {
    final newMap = Map<String, List<EditorDiagnostic>>.from(state.diagnosticsByFile);
    newMap[fileDiagnostics.uri] = fileDiagnostics.diagnostics;
    state = state.copyWith(diagnosticsByFile: newMap);
  }

  /// Clear diagnostics for a specific file.
  void clearFile(String uri) {
    final newMap = Map<String, List<EditorDiagnostic>>.from(state.diagnosticsByFile);
    newMap.remove(uri);
    state = state.copyWith(diagnosticsByFile: newMap);
  }

  /// Clear all diagnostics.
  void clearAll() {
    state = const DiagnosticsState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for diagnostics state.
final diagnosticsProvider =
    StateNotifierProvider<DiagnosticsNotifier, DiagnosticsState>((ref) {
  // Note: The notifier starts without a subscription.
  // It will be subscribed when the first LSP client starts.
  // This is handled in the main.dart or an init widget.
  return DiagnosticsNotifier();
});

/// Helper to convert EditorDiagnostic to LineDecoration for rendering.
List<LineDecoration> diagnosticsToDecorations(
  List<EditorDiagnostic> diagnostics,
  String sourceText,
) {
  // Build line offset map
  final lineOffsets = <int>[0];
  for (var i = 0; i < sourceText.length; i++) {
    if (sourceText.codeUnitAt(i) == 10) {
      lineOffsets.add(i + 1);
    }
  }

  return diagnostics.map((d) {
    // Decode line/char from encoded int
    final (startLine, startChar) = LspClient.decodeLineChar(d.start);
    final (endLine, endChar) = LspClient.decodeLineChar(d.end);

    // Convert to character offsets
    int startOffset = 0;
    int endOffset = 0;

    if (startLine < lineOffsets.length) {
      startOffset = lineOffsets[startLine] + startChar;
    }
    if (endLine < lineOffsets.length) {
      endOffset = lineOffsets[endLine] + endChar;
    }

    // Clamp to source length
    startOffset = startOffset.clamp(0, sourceText.length);
    endOffset = endOffset.clamp(0, sourceText.length);

    // Ensure end >= start
    if (endOffset < startOffset) endOffset = startOffset;

    final color = switch (d.severity) {
      DiagnosticSeverity.error => const Color(0xFFE53935), // Red
      DiagnosticSeverity.warning => const Color(0xFFFFA726), // Orange
      DiagnosticSeverity.information => const Color(0xFF42A5F5), // Blue
      DiagnosticSeverity.hint => const Color(0xFF78909C), // Grey
    };

    return LineDecoration(
      id: 'diag_${d.hashCode}',
      start: startOffset,
      end: endOffset,
      type: LineDecorationType.wavyUnderline,
      color: color,
      tooltip: d.message,
    );
  }).toList();
}

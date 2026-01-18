/// Diagnostic entity for representing LSP errors, warnings, hints, and info.
library;

/// Severity levels for diagnostics.
enum DiagnosticSeverity {
  error,
  warning,
  information,
  hint,
}

/// A single diagnostic message from the LSP server.
class EditorDiagnostic {
  /// Start offset in the document (character index).
  final int start;

  /// End offset in the document (character index).
  final int end;

  /// The diagnostic message.
  final String message;

  /// The severity of the diagnostic.
  final DiagnosticSeverity severity;

  /// Optional diagnostic code from the LSP server.
  final String? code;

  /// Optional source (e.g., "dart", "eslint").
  final String? source;

  const EditorDiagnostic({
    required this.start,
    required this.end,
    required this.message,
    required this.severity,
    this.code,
    this.source,
  });

  @override
  String toString() => 'EditorDiagnostic($start-$end, $severity, $message)';
}

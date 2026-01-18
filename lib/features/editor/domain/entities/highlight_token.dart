/// Unified highlight token format for all highlight providers.
///
/// This entity is used by RegexHighlightProvider, LspHighlightProvider,
/// and (future) TreeSitterHighlightProvider.
library;

/// A single highlighted token in the code.
class HighlightToken {
  /// Start offset in the source code (inclusive).
  /// Start offset in the source code (inclusive).
  int start;

  /// End offset in the source code (exclusive).
  int end;

  /// Token type: 'keyword', 'function', 'string', 'comment', etc.
  final String type;

  /// Optional modifiers: 'readonly', 'deprecated', 'declaration', etc.
  final List<String> modifiers;

  HighlightToken({
    required this.start,
    required this.end,
    required this.type,
    this.modifiers = const [],
  });

  int get length => end - start;

  @override
  String toString() => 'HighlightToken($start-$end, $type, $modifiers)';
}

/// Standard token types (compatible with LSP and TextMate).
abstract final class TokenTypes {
  static const namespace = 'namespace';
  static const type = 'type';
  static const class_ = 'class';
  static const enum_ = 'enum';
  static const interface_ = 'interface';
  static const struct = 'struct';
  static const typeParameter = 'typeParameter';
  static const parameter = 'parameter';
  static const variable = 'variable';
  static const property = 'property';
  static const enumMember = 'enumMember';
  static const event = 'event';
  static const function_ = 'function';
  static const method = 'method';
  static const macro = 'macro';
  static const keyword = 'keyword';
  static const modifier = 'modifier';
  static const comment = 'comment';
  static const string = 'string';
  static const number = 'number';
  static const regexp = 'regexp';
  static const operator_ = 'operator';
  static const decorator = 'decorator';
}

/// Standard token modifiers.
abstract final class TokenModifiers {
  static const declaration = 'declaration';
  static const definition = 'definition';
  static const readonly = 'readonly';
  static const static_ = 'static';
  static const deprecated = 'deprecated';
  static const abstract_ = 'abstract';
  static const async_ = 'async';
  static const modification = 'modification';
  static const documentation = 'documentation';
  static const defaultLibrary = 'defaultLibrary';
}

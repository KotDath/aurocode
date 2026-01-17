/// Theme for mapping highlight token types to text styles.
///
/// Based on Atom One Dark color scheme.
library;

import 'package:flutter/material.dart';

/// Maps token types and modifiers to TextStyle.
class HighlightTheme {
  final Map<String, TextStyle> _styles;
  final TextStyle _defaultStyle;

  const HighlightTheme({
    required Map<String, TextStyle> styles,
    TextStyle defaultStyle = const TextStyle(),
  })  : _styles = styles,
        _defaultStyle = defaultStyle;

  /// Get style for a token type with optional modifiers.
  TextStyle getStyle(String type, [List<String> modifiers = const []]) {
    var style = _styles[type] ?? _defaultStyle;

    for (final modifier in modifiers) {
      final modStyle = _modifierStyles[modifier];
      if (modStyle != null) {
        style = style.merge(modStyle);
      }
    }

    return style;
  }

  static const _modifierStyles = {
    'declaration': TextStyle(fontWeight: FontWeight.w600),
    'definition': TextStyle(fontWeight: FontWeight.w600),
    'readonly': TextStyle(fontStyle: FontStyle.italic),
    'static': TextStyle(fontStyle: FontStyle.italic),
    'deprecated': TextStyle(decoration: TextDecoration.lineThrough),
    'abstract': TextStyle(fontStyle: FontStyle.italic),
    'documentation': TextStyle(fontStyle: FontStyle.italic),
  };

  /// Atom One Dark theme.
  static const atomOneDark = HighlightTheme(
    defaultStyle: TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 14,
      color: Color(0xFFABB2BF),
    ),
    styles: {
      // Keywords and modifiers
      'keyword': TextStyle(color: Color(0xFFC678DD)),
      'modifier': TextStyle(color: Color(0xFFC678DD)),

      // Types
      'type': TextStyle(color: Color(0xFF56B6C2)),
      'class': TextStyle(color: Color(0xFFE5C07B)),
      'interface': TextStyle(color: Color(0xFFE5C07B)),
      'struct': TextStyle(color: Color(0xFFE5C07B)),
      'enum': TextStyle(color: Color(0xFFE5C07B)),
      'typeParameter': TextStyle(color: Color(0xFFE5C07B)),

      // Functions
      'function': TextStyle(color: Color(0xFF61AFEF)),
      'method': TextStyle(color: Color(0xFF61AFEF)),
      'macro': TextStyle(color: Color(0xFF61AFEF)),

      // Variables
      'variable': TextStyle(color: Color(0xFFE06C75)),
      'parameter': TextStyle(color: Color(0xFFABB2BF)),
      'property': TextStyle(color: Color(0xFFE06C75)),
      'enumMember': TextStyle(color: Color(0xFFD19A66)),

      // Literals
      'string': TextStyle(color: Color(0xFF98C379)),
      'number': TextStyle(color: Color(0xFFD19A66)),
      'regexp': TextStyle(color: Color(0xFF56B6C2)),

      // Comments
      'comment': TextStyle(color: Color(0xFF5C6370)),

      // Operators
      'operator': TextStyle(color: Color(0xFFABB2BF)),

      // Namespace
      'namespace': TextStyle(color: Color(0xFFE06C75)),

      // Decorators
      'decorator': TextStyle(color: Color(0xFFC678DD)),
    },
  );
}

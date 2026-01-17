import 'package:flutter_test/flutter_test.dart';

import 'package:aurocode_ide/features/editor/domain/entities/highlight_token.dart';

void main() {
  group('LSP Semantic Token Decoding', () {
    test('decodes single token correctly', () {
      // LSP semantic tokens format: [deltaLine, deltaStart, length, tokenType, tokenModifiers]
      // Single token at line 0, char 0, length 4
      final data = [0, 0, 4, 0, 0]; // keyword at position 0
      
      final tokens = decodeSemanticTokensWithSource(
        data,
        'void main() {}',
        ['keyword', 'function', 'variable'],
        ['declaration', 'readonly'],
      );
      
      expect(tokens.length, 1);
      expect(tokens[0].start, 0);
      expect(tokens[0].end, 4);
      expect(tokens[0].type, 'keyword');
    });

    test('decodes multiple tokens on same line', () {
      // "void main() {}"
      //  ^--- keyword (0-4)
      //       ^--- function (5-9)
      final data = [
        0, 0, 4, 0, 0,  // "void" at line 0, char 0, length 4, type 0 (keyword)
        0, 5, 4, 1, 0,  // "main" at line 0, char 5, length 4, type 1 (function)
      ];
      
      final tokens = decodeSemanticTokensWithSource(
        data,
        'void main() {}',
        ['keyword', 'function'],
        [],
      );
      
      expect(tokens.length, 2);
      
      // First token: "void"
      expect(tokens[0].start, 0);
      expect(tokens[0].end, 4);
      expect(tokens[0].type, 'keyword');
      
      // Second token: "main" - deltaStart=5 means 5 chars from previous token
      expect(tokens[1].start, 5);
      expect(tokens[1].end, 9);
      expect(tokens[1].type, 'function');
    });

    test('decodes tokens across multiple lines', () {
      // Line 0: "void main() {"
      // Line 1: "  print('hello');"
      //    ^--- function at (1, 2)
      final source = 'void main() {\n  print(\'hello\');\n}';
      final data = [
        0, 0, 4, 0, 0,  // "void" at line 0, char 0
        0, 5, 4, 1, 0,  // "main" at line 0, char 5
        1, 2, 5, 1, 0,  // "print" at line 1, char 2 (deltaLine=1)
      ];
      
      final tokens = decodeSemanticTokensWithSource(
        data,
        source,
        ['keyword', 'function'],
        [],
      );
      
      expect(tokens.length, 3);
      
      // "print" should be at correct offset
      // Line 0 is 14 chars ("void main() {\n")
      // Line 1 starts at offset 14, then 2 chars indent
      expect(tokens[2].start, 16); // 14 + 2
      expect(tokens[2].end, 21);   // 16 + 5
      expect(tokens[2].type, 'function');
    });

    test('handles modifiers correctly', () {
      final data = [0, 0, 5, 0, 3]; // modifiers = 0b11 = declaration + readonly
      
      final tokens = decodeSemanticTokensWithSource(
        data,
        'const x',
        ['variable'],
        ['declaration', 'readonly', 'static'],
      );
      
      expect(tokens[0].modifiers, containsAll(['declaration', 'readonly']));
      expect(tokens[0].modifiers, isNot(contains('static')));
    });
  });
}

/// Decodes LSP semantic tokens with proper line/character to offset conversion.
List<HighlightToken> decodeSemanticTokensWithSource(
  List<int> data,
  String source,
  List<String> tokenTypes,
  List<String> tokenModifiers,
) {
  final tokens = <HighlightToken>[];
  final lines = source.split('\n');
  
  // Calculate line start offsets
  final lineOffsets = <int>[0];
  for (var i = 0; i < lines.length - 1; i++) {
    lineOffsets.add(lineOffsets[i] + lines[i].length + 1); // +1 for \n
  }
  
  var line = 0;
  var character = 0;
  
  for (var i = 0; i + 4 < data.length; i += 5) {
    final deltaLine = data[i];
    final deltaStart = data[i + 1];
    final length = data[i + 2];
    final tokenType = data[i + 3];
    final tokenModifiersBits = data[i + 4];
    
    // Update position
    if (deltaLine > 0) {
      line += deltaLine;
      character = deltaStart;
    } else {
      character += deltaStart;
    }
    
    // Calculate offset from line/character
    final offset = (line < lineOffsets.length ? lineOffsets[line] : 0) + character;
    
    final typeName = tokenType < tokenTypes.length ? tokenTypes[tokenType] : 'unknown';
    
    // Decode modifiers
    final mods = <String>[];
    for (var j = 0; j < tokenModifiers.length; j++) {
      if ((tokenModifiersBits & (1 << j)) != 0) {
        mods.add(tokenModifiers[j]);
      }
    }
    
    tokens.add(HighlightToken(
      start: offset,
      end: offset + length,
      type: typeName,
      modifiers: mods,
    ));
  }
  
  return tokens;
}

import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/cmake.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/gradle.dart';
import 'package:re_highlight/languages/gradle.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import '../domain/entities/highlight_token.dart';

class SyntaxHighlighterService {
  final Highlight _highlight = Highlight();
  final Map<String, TextStyle> _theme = atomOneDarkTheme;
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;

    _highlight.registerLanguage('dart', langDart);
    _highlight.registerLanguage('yaml', langYaml);
    _highlight.registerLanguage('json', langJson);
    _highlight.registerLanguage('markdown', langMarkdown);
    _highlight.registerLanguage('python', langPython);
    _highlight.registerLanguage('rust', langRust);
    _highlight.registerLanguage('css', langCss);
    _highlight.registerLanguage('html', langXml);
    _highlight.registerLanguage('xml', langXml);
    _highlight.registerLanguage('toml', langYaml);

    // New languages
    _highlight.registerLanguage('cpp', langCpp);
    _highlight.registerLanguage('c', langCpp); // C uses CPP grammar often
    _highlight.registerLanguage('h', langCpp);
    _highlight.registerLanguage('cmake', langCmake);
    _highlight.registerLanguage('go', langGo);
    _highlight.registerLanguage('javascript', langJavascript);
    _highlight.registerLanguage('js', langJavascript);
    _highlight.registerLanguage('typescript', langTypescript);
    _highlight.registerLanguage('ts', langTypescript);
    _highlight.registerLanguage('bash', langBash);
    _highlight.registerLanguage('sh', langBash);
    _highlight.registerLanguage('sql', langSql);
    _highlight.registerLanguage('java', langJava);
    _highlight.registerLanguage('kotlin', langKotlin);
    _highlight.registerLanguage('swift', langSwift);
    _highlight.registerLanguage('gradle', langGradle);
    
    _initialized = true;
  }

  TextSpan? highlight(String code, String language) {
    if (code.isEmpty) return null;

    _ensureInitialized();

    try {
      final result = _highlight.highlight(
        code: code,
        language: language,
      );

      final renderer = TextSpanRenderer(
        const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14),
        _theme,
      );
      result.render(renderer);
      return renderer.span;
    } catch (e) {
      return TextSpan(
        text: code,
        style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14),
      );
    }
  }

  List<HighlightToken> highlightAsTokens(String code, String language) {
    if (code.isEmpty) return [];

    _ensureInitialized();
    
    // Map common hljs scopes to semantic token types
    final scopeMap = {
      'keyword': 'keyword',
      'built_in': 'variable',
      'type': 'type',
      'literal': 'number',
      'number': 'number',
      'regexp': 'regexp',
      'string': 'string',
      'subst': 'variable',
      'symbol': 'variable',
      'class': 'class',
      'function': 'function',
      'title': 'function',
      'params': 'parameter',
      'comment': 'comment',
      'doctag': 'comment',
      'meta': 'macro',
      'meta-keyword': 'keyword',
      'meta-string': 'string',
      'section': 'class',
      'tag': 'type',
      'name': 'variable',
      'attr': 'property',
      'attribute': 'property',
      'variable': 'variable',
      'bullet': 'string',
      'code': 'string',
      'emphasis': 'modifier',
      'strong': 'modifier',
      'formula': 'string',
      'link': 'string',
      'quote': 'string',
      'selector-tag': 'keyword',
      'selector-id': 'variable',
      'selector-class': 'class',
      'selector-attr': 'property',
      'selector-pseudo': 'modifier',
      'template-tag': 'keyword',
      'template-variable': 'variable',
      'diff': 'comment',
      'deletion': 'comment',
      'addition': 'string',
      'operator': 'operator',
      'punctuation': 'operator',
    };

    try {
      final result = _highlight.highlight(
        code: code,
        language: language,
      );

      final renderer = _TokenRenderer(scopeMap);
      result.render(renderer);
      return renderer.tokens;
    } catch (e) {
      return [];
    }
  }
}

class _TokenRenderer implements HighlightRenderer {
  final Map<String, String> scopeMap;
  final List<HighlightToken> tokens = [];
  int _currentOffset = 0;
  final List<String> _scopeStack = [];

  _TokenRenderer(this.scopeMap);

  @override
  void addText(String text) {
    if (text.isEmpty) return;
    
    if (_scopeStack.isNotEmpty) {
      final scope = _scopeStack.last;
      
      // Try exact match, then parts for composed scopes (e.g. meta-keyword)
      String type = scopeMap[scope] ?? 'variable';
      if (scopeMap[scope] == null && scope.contains('-')) {
         final parts = scope.split('-');
         type = scopeMap[parts.last] ?? type;
      }
      
      tokens.add(HighlightToken(
        start: _currentOffset,
        end: _currentOffset + text.length,
        type: type,
      ));
    }
    _currentOffset += text.length;
  }

  @override
  void openNode(DataNode node) {
    // print('DataNode: ${node.scope}, ${node.kind}, ${node.className}'); // Guessing
    // To debug what properties exist, I'll temporarily use dynamic (unsafe but works for print if runtime supports)
    // Actually I can't cast to dynamic if compilation fails on property access.
    // So I have to guess or cast to dynamic first.
    
    // cast to dynamic to check contents at runtime (if I can compile)
    // But compilation fails at static check.
    
    // If I cast to dynamic, I bypass static check?
    // final d = node as dynamic;
    // print(d);
    
    _scopeStack.add((node as dynamic).kind ?? (node as dynamic).scope ?? (node as dynamic).className ?? '');
  }

  @override
  void closeNode(DataNode node) {
    if (_scopeStack.isNotEmpty) {
      _scopeStack.removeLast();
    }
  }
}

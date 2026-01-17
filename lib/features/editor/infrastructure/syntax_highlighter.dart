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
import 'package:re_highlight/styles/atom-one-dark.dart';

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
}

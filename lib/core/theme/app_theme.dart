import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.dark(
        primary: Colors.blue.shade400,
        secondary: Colors.blue.shade300,
        surface: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      cardColor: const Color(0xFF252526),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3E3E42),
        thickness: 1,
      ),
    );
  }

  static const TextStyle codeStyle = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 14,
    height: 1.5,
  );
}

enum TerminalTextStyle {
  normal,
  bold,
  dim,
  italic,
  underline,
}

class TerminalLine {
  final String text;
  final TerminalTextStyle style;

  const TerminalLine({
    required this.text,
    this.style = TerminalTextStyle.normal,
  });
}

class TerminalSession {
  final String id;
  final String shell;
  final List<TerminalLine> output;
  final bool isActive;

  const TerminalSession({
    required this.id,
    required this.shell,
    this.output = const [],
    this.isActive = false,
  });

  TerminalSession copyWith({
    String? id,
    String? shell,
    List<TerminalLine>? output,
    bool? isActive,
  }) {
    return TerminalSession(
      id: id ?? this.id,
      shell: shell ?? this.shell,
      output: output ?? this.output,
      isActive: isActive ?? this.isActive,
    );
  }

  TerminalSession addOutput(String text) {
    return copyWith(
      output: [...output, TerminalLine(text: text)],
    );
  }
}

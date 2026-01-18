/// A summary of the text content in a Rope node.
///
/// This acts as the "Monoid" for the SumTree, allowing O(1) composition
/// and O(log N) lookup of metrics.
class TextSummary {
  /// Total length in UTF-16 code units (Dart String length).
  final int length;

  /// Total number of newlines ('\n').
  final int lines;

  /// Length of the last line (distance from last newline to end).
  /// If there are no newlines, this equals [length].
  final int lastLineLength;

  const TextSummary({
    required this.length,
    required this.lines,
    required this.lastLineLength,
  });

  /// Empty summary.
  static const empty = TextSummary(length: 0, lines: 0, lastLineLength: 0);

  /// Creates a summary from a string chunk.
  factory TextSummary.fromText(String text) {
    var lines = 0;
    var lastLineLength = 0;
    
    // We intentionally iterate manually or use efficient built-ins.
    // For large chunks, this is done once at leaf creation.
    final len = text.length;
    var lastNewlineIndex = -1;
    
    for (var i = 0; i < len; i++) {
      if (text.codeUnitAt(i) == 0x0A) { // \n
        lines++;
        lastNewlineIndex = i;
      }
    }

    if (lines == 0) {
      lastLineLength = len;
    } else {
      lastLineLength = len - lastNewlineIndex - 1;
    }

    return TextSummary(
      length: len,
      lines: lines,
      lastLineLength: lastLineLength,
    );
  }

  /// Composition (Associative add).
  /// Combines two summaries (left + right).
  TextSummary operator +(TextSummary other) {
    return TextSummary(
      length: length + other.length,
      lines: lines + other.lines,
      lastLineLength: other.lines > 0 
          ? other.lastLineLength 
          : lastLineLength + other.length,
    );
  }

  @override
  String toString() => 'TextSummary(len: $length, lines: $lines, lastLineLen: $lastLineLength)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextSummary &&
          runtimeType == other.runtimeType &&
          length == other.length &&
          lines == other.lines &&
          lastLineLength == other.lastLineLength;

  @override
  int get hashCode => Object.hash(length, lines, lastLineLength);
}

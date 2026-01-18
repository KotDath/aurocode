/// Represents a change in the rope content.
class RopeChange {
  final int start;
  final int end; // exclusive end of the range being replaced (old text)
  final String text; // new text inserted
  final String? deletedText; // content that was replaced

  const RopeChange({
    required this.start,
    required this.end,
    required this.text,
    this.deletedText,
  });
}

/// Line decoration entity for visual markers in the editor.
/// Inspired by code_forge's LineDecoration system.
library;

import 'package:flutter/material.dart';

/// Types of decorations that can be applied to text ranges.
enum LineDecorationType {
  /// Solid underline
  underline,

  /// Wavy/squiggly underline (like error indicators)
  wavyUnderline,

  /// Background highlight
  background,

  /// Left border/bar indicator (like git diff)
  leftBorder,
}

/// Represents a decoration applied to a range of text in the editor.
///
/// Used for diagnostics (errors/warnings), search results, git diffs, etc.
class LineDecoration {
  /// Unique identifier for this decoration.
  final String id;

  /// Start offset in the document (character index).
  final int start;

  /// End offset in the document (character index).
  final int end;

  /// The type of decoration to apply.
  final LineDecorationType type;

  /// The color of the decoration.
  final Color color;

  /// Thickness for border/underline decorations (default: 2.0).
  final double thickness;

  /// Optional priority for overlapping decorations (higher = on top).
  final int priority;

  /// Optional tooltip message shown on hover.
  final String? tooltip;

  const LineDecoration({
    required this.id,
    required this.start,
    required this.end,
    required this.type,
    required this.color,
    this.thickness = 2.0,
    this.priority = 0,
    this.tooltip,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineDecoration &&
          id == other.id &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(id, start, end);
}

import 'rope_node.dart';
import 'text_summary.dart';
import 'internal_node.dart';

const int kMaxLeafSize = 512;
const int kMinLeafSize = 256;

/// A leaf node containing actual text data.
class LeafNode extends RopeNode {
  final String text;
  final TextSummary _summary;

  LeafNode(this.text) : _summary = TextSummary.fromText(text);

  LeafNode._(this.text, this._summary);

  @override
  TextSummary get summary => _summary;
  
  @override
  int get height => 0;

  @override
  List<RopeNode> insert(int offset, String newText) {
    if (offset < 0 || offset > length) {
      throw RangeError.index(offset, text, 'offset');
    }

    final combinedText = text.substring(0, offset) + newText + text.substring(offset);
    
    // If small enough, return one leaf.
    if (combinedText.length <= kMaxLeafSize) {
      return [LeafNode(combinedText)];
    }

    // Split into two leaves if too large.
    final splitPoint = combinedText.length ~/ 2;
    // Align split to UTF-16 surrogate pairs if needed (Dart strings are UTF-16, 
    // but splitting strictly in half is usually fine for rope structure unless 
    // we want to be very precise about not splitting surrogates. 
    // Simple split is okay for now, String.substring handles indices safely).
    
    return [
      LeafNode(combinedText.substring(0, splitPoint)),
      LeafNode(combinedText.substring(splitPoint)),
    ];
  }

  @override
  RopeNode? delete(int start, int end) {
    if (start < 0 || end > length || start > end) {
      throw RangeError('Invalid range: $start-$end');
    }
    if (start == 0 && end == length) {
      return null;
    }
    final newText = text.substring(0, start) + text.substring(end);
    return LeafNode(newText);
  }

  @override
  RopeNode slice(int start, int end) {
    if (start < 0 || end > length || start > end) {
      throw RangeError('Invalid range: $start-$end');
    }
    return LeafNode(text.substring(start, end));
  }

  @override
  String charAt(int index) {
    return text[index];
  }

  @override
  String toText() => text;

  @override
  int lineIndexAt(int offset) {
    // Local search within leaf
    if (offset == 0) return 0;
    // This is O(leaf_size), which is O(1) relative to total text.
    var lines = 0;
    for (var i = 0; i < offset && i < text.length; i++) {
        if (text.codeUnitAt(i) == 0x0A) lines++;
    }
    return lines;
  }

  @override
  int lineStartOffset(int lineIndex) {
    if (lineIndex == 0) return 0;
    
    var currentLine = 0;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        currentLine++;
        if (currentLine == lineIndex) return i + 1;
      }
    }
    // If not found in this node (shouldn't happen if logic is correct upstream),
    // return length.
    return length;
  }

  @override
  RopeNode concat(RopeNode other) {
    // If other is leaf and combined size is small, merge.
    if (other is LeafNode) {
      if (length + other.length <= kMaxLeafSize) {
        return LeafNode(text + other.text);
      }
    }
    // If other is taller (InternalNode), we must prepend ourselves to it deeply.
    if (other is InternalNode) {
         final newFirst = concat(other.children.first);
         if (newFirst.height == other.height) {
             // The merge caused the first child to grow to parent's height.
             // We must effectively concat `newFirst` (H) with `other.suffix` (H).
             if (other.children.length == 1) return newFirst;
             
             // Create a suffix node of the remaining children.
             // Note: internal nodes with 1 child are generally valid in our relaxed B-Tree during construction/ops,
             // checking InternalNode constructor or usage.
             final suffix = InternalNode(other.children.sublist(1));
             return newFirst.concat(suffix);
         } else {
             // Standard case: newFirst fits as the first child.
             final newChildren = List<RopeNode>.from(other.children);
             newChildren[0] = newFirst;
             return InternalNode(newChildren);
         }
    }

    // Otherwise (same height 0), create a parent InternalNode.
    return InternalNode([this, other]);
  }
}

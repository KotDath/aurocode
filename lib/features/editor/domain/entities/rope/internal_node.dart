import 'rope_node.dart';
import 'text_summary.dart';

const int kMaxChildren = 8;
const int kMinChildren = 4;

/// Internal node of the B-Tree.
class InternalNode extends RopeNode {
  final List<RopeNode> children;
  final TextSummary _summary;
  final int _height;

  InternalNode(this.children)
      : _summary = _computeSummary(children),
        _height = children.first.height + 1 {
    assert(children.isNotEmpty);
    // In strict B-Trees, children should have same height.
    assert(children.every((c) => c.height == children.first.height));
  }

  static TextSummary _computeSummary(List<RopeNode> children) {
    var sum = TextSummary.empty;
    for (var child in children) {
      sum += child.summary;
    }
    return sum;
  }

  @override
  TextSummary get summary => _summary;
  
  @override
  int get length => _summary.length;
  
  @override
  int get lineCount => _summary.lines;

  @override
  int get height => _height;

  @override
  List<RopeNode> insert(int offset, String text) {
    if (offset < 0 || offset > length) {
      throw RangeError.index(offset, this, 'offset');
    }

    // 1. Find child
    var remainingOffset = offset;
    var index = 0;
    
    for (var i = 0; i < children.length; i++) {
      final childLen = children[i].length;
      if (remainingOffset <= childLen) {
        index = i;
        break;
      }
      remainingOffset -= childLen;
    }
    if (index == children.length) index = children.length - 1;

    // 2. Recursive insert
    final newChildren = children[index].insert(remainingOffset, text);

    // 3. Update children list
    final newChildList = List<RopeNode>.from(children);
    newChildList.replaceRange(index, index + 1, newChildren);

    // 4. Split if overflow
    if (newChildList.length <= kMaxChildren) {
      return [InternalNode(newChildList)];
    }

    final splitPoint = newChildList.length ~/ 2;
    return [
      InternalNode(newChildList.sublist(0, splitPoint)),
      InternalNode(newChildList.sublist(splitPoint)),
    ];
  }

  @override
  RopeNode? delete(int start, int end) {
    // Implemented via slice + concat for robustness
    final leftPart = start > 0 ? slice(0, start) : null;
    final rightPart = end < length ? slice(end, length) : null;

    if (leftPart == null && rightPart == null) return null;
    if (leftPart == null) return rightPart;
    if (rightPart == null) return leftPart;

    return leftPart.concat(rightPart);
  }

  @override
  RopeNode slice(int start, int end) {
    if (start < 0 || end > length || start > end) {
      throw RangeError('Invalid range: $start-$end');
    }
    if (start == 0 && end == length) return this;

    final resultNodes = <RopeNode>[];
    
    var currentPos = 0;
    for (var child in children) {
      final childLen = child.length;
      final childEnd = currentPos + childLen;

      if (childEnd > start && currentPos < end) {
        final childStartSlice = (start - currentPos).clamp(0, childLen);
        final childEndSlice = (end - currentPos).clamp(0, childLen);
        resultNodes.add(child.slice(childStartSlice, childEndSlice));
      }

      currentPos += childLen;
      if (currentPos >= end) break;
    }

    if (resultNodes.isEmpty) throw StateError("Empty slice result");
    
    // Concatenate results
    var res = resultNodes[0];
    for (var i = 1; i < resultNodes.length; i++) {
        res = res.concat(resultNodes[i]);
    }
    return res;
  }

  @override
  RopeNode concat(RopeNode other) {
    if (height == other.height) {
      // Try to merge children lists if other is also internal
      if (other is InternalNode) {
         final totalChildren = children.length + other.children.length;
         if (totalChildren <= kMaxChildren) {
             return InternalNode([...children, ...other.children]);
         }
      }
      return InternalNode([this, other]);
    }
    
    if (height > other.height) {
      // Append matching height tree recursively to last child
      final newLast = children.last.concat(other);
      if (newLast.height == height) {
          // It grew to our height. We cannot be its parent.
          // We must merge our remaining children (as a node of height H) with newLast (height H).
          if (children.length == 1) return newLast;
          final prefix = InternalNode(children.sublist(0, children.length - 1));
          return prefix.concat(newLast);
      } else {
          // Wrapped in existing height
          final newChildren = List<RopeNode>.from(children);
          newChildren[newChildren.length - 1] = newLast;
          return InternalNode(newChildren);
      }
    }
    
    // If other is taller, prepend this to other's first child
    if (other is InternalNode) { // check implicitly true if height < other.height
         final newFirst = concat(other.children.first);
         if (newFirst.height == other.height) {
             // It grew to other's height.
             if (other.children.length == 1) return newFirst;
             final suffix = InternalNode(other.children.sublist(1));
             return newFirst.concat(suffix);
         } else {
             final newChildren = List<RopeNode>.from(other.children);
             newChildren[0] = newFirst;
             return InternalNode(newChildren);
         }
    }
    
    return InternalNode([this, other]);
  }

  @override
  String charAt(int index) {
      var remaining = index;
      for (var child in children) {
          if (remaining < child.length) return child.charAt(remaining);
          remaining -= child.length;
      }
      throw RangeError.index(index, this);
  }

  @override
  String toText() {
      final buffer = StringBuffer();
      for (var child in children) buffer.write(child.toText());
      return buffer.toString();
  }

  @override
  int lineIndexAt(int offset) {
     var remaining = offset;
     var lines = 0;
     for (var child in children) {
         if (remaining <= child.length) {
             return lines + child.lineIndexAt(remaining);
         }
         remaining -= child.length;
         lines += child.lineCount;
     }
     return lines;
  }

  @override
  int lineStartOffset(int lineIndex) {
      if (lineIndex == 0) return 0;
      var remainingLines = lineIndex;
      var offset = 0;
      for (var child in children) {
          if (remainingLines <= child.lineCount) {
              return offset + child.lineStartOffset(remainingLines);
          }
          offset += child.length;
          remainingLines -= child.lineCount;
      }
      return offset;
  }
}

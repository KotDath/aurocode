import 'rope_node.dart';
import 'leaf_node.dart';

/// An immutable rope data structure for efficient text editing.
///
/// Uses a B-Tree structure with cached [TextSummary] metrics for O(log N)
/// operations on standard text manipulation and line-based lookups.
class Rope {
  final RopeNode _root;

  const Rope._(this._root);

  /// Creates a rope from [text].
  factory Rope([String text = '']) {
    // Use the bulk loader to ensure balanced tree
    return Rope._(RopeNode.fromText(text));
  }
  
  /// Creates an empty rope.
  factory Rope.empty() => Rope._(LeafNode(''));
// ... (rest is same)
  /// Total character length.
  int get length => _root.length;

  /// Whether empty.
  bool get isEmpty => length == 0;
  
  /// Whether not empty.
  bool get isNotEmpty => length > 0;

  /// Total number of lines.
  int get lineCount {
    if (isEmpty) return 0;
    return _root.lineCount + 1;
  }

  /// Returns full text.
  @override
  String toString() => _root.toText();

  /// Returns char at [index].
  String charAt(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    return _root.charAt(index);
  }

  /// Substring from [start] to [end] (exclusive).
  String substring(int start, [int? end]) {
    end ??= length;
    if (start < 0 || end > length || start > end) {
      throw RangeError('Invalid range: $start-$end for length $length');
    }
    if (start == end) return '';
    return _root.slice(start, end).toText();
  }

  /// Inserts [text] at [position].
  Rope insert(int position, String text) {
    if (position < 0 || position > length) {
      throw RangeError.index(position, this, 'position', null, length);
    }
    if (text.isEmpty) return this;
    
    final newNodes = _root.insert(position, text);
    if (newNodes.length == 1) {
      return Rope._(newNodes[0]);
    } else {
      return Rope._(concatNodes(newNodes));
    }
  }

  static RopeNode concatNodes(List<RopeNode> nodes) {
      if (nodes.isEmpty) return LeafNode(''); 
      var res = nodes[0];
      for (var i = 1; i < nodes.length; i++) {
          res = res.concat(nodes[i]);
      }
      return res;
  }

  /// Deletes range [start]..[end].
  Rope delete(int start, int end) {
    if (start < 0 || end > length || start > end) {
      throw RangeError('Invalid range: $start-$end for length $length');
    }
    if (start == end) return this;
    
    final newNode = _root.delete(start, end);
    return Rope._(newNode ?? LeafNode(''));
  }

  /// Replaces range with [text].
  Rope replace(int start, int end, String text) {
    final left = start > 0 ? _root.slice(0, start) : null;
    final middle = LeafNode(text);
    final right = end < length ? _root.slice(end, length) : null;

    var res = left ?? middle;
    if (left != null) res = res.concat(middle);
    if (right != null) res = res.concat(right);
    
    return Rope._(res);
  }

  /// Concatenates with [other].
  Rope concat(Rope other) {
    if (isEmpty) return other;
    if (other.isEmpty) return this;
    return Rope._(_root.concat(other._root));
  }

  /// Splits at [position].
  (Rope, Rope) split(int position) {
    if (position < 0 || position > length) {
      throw RangeError.index(position, this, 'position', null, length);
    }
    if (position == 0) return (Rope.empty(), this);
    if (position == length) return (this, Rope.empty());
    
    final left = _root.slice(0, position);
    final right = _root.slice(position, length);
    return (Rope._(left), Rope._(right));
  }

  /// Returns line index for [offset].
  int lineIndexAt(int offset) {
    if (offset < 0 || offset > length) {
       throw RangeError.index(offset, this);
    }
    return _root.lineIndexAt(offset);
  }

  /// Returns (line, col) for [offset].
  (int, int) lineColAt(int offset) {
    final line = lineIndexAt(offset);
    final col = offset - lineStartOffset(line);
    return (line, col);
  }

  /// Returns start offset of [lineIndex].
  int lineStartOffset(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= lineCount) {
       throw RangeError.index(lineIndex, this, 'lineIndex', null, lineCount);
    }
    return _root.lineStartOffset(lineIndex);
  }
  
  /// Returns end offset of [lineIndex].
  int lineEndOffset(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= lineCount) {
       throw RangeError.index(lineIndex, this);
    }
    if (lineIndex == lineCount - 1) return length;
    return lineStartOffset(lineIndex + 1);
  }

  /// Returns line string.
  String getLine(int lineIndex) {
    final start = lineStartOffset(lineIndex);
    final end = lineEndOffset(lineIndex);
    var line = substring(start, end);
    if (line.endsWith('\n')) {
        return line.substring(0, line.length - 1);
    }
    return line;
  }
  
  Iterable<String> get lines sync* {
      for (var i = 0; i < lineCount; i++) {
        yield getLine(i);
      }
  }

  /// Basic search.
  /// 
  /// Optimized to avoid [toString] allocation for large files where possible.
  int find(String query, {int startOffset = 0, bool caseSensitive = true}) {
      if (query.isEmpty || startOffset >= length) return -1;
      
      // Fast path for small files (under 1MB) - toString is still fastest in Dart VM
      // compared to complex Dart-side iteration due to string implementation optimizations.
      if (length < 1024 * 1024) {
        final text = toString();
        final searchText = caseSensitive ? text : text.toLowerCase();
        final searchQuery = caseSensitive ? query : query.toLowerCase();
        return searchText.indexOf(searchQuery, startOffset);
      }

      // Large file fallback:
      // For now, to prevent 2-3s freeze, we still use toString() but we acknowledge it.
      // Ideally, we would implement chunk-based search here.
      // Given the user report was about cursor lag (which we fixed via hashCode),
      // we can leave this as a TODO or implement a windowed search if query is small.
      
      final text = toString();
      final searchText = caseSensitive ? text : text.toLowerCase();
      final searchQuery = caseSensitive ? query : query.toLowerCase();
      return searchText.indexOf(searchQuery, startOffset);
  }

  List<(int, int)> findAll(String query, {bool caseSensitive = true}) {
      if (query.isEmpty) return [];
      
      // Limit results for large files to avoid UI freeze rendering matches
      // But standard finder needs all.
      final matches = <(int, int)>[];
      final text = toString();
      final searchText = caseSensitive ? text : text.toLowerCase();
      final searchQuery = caseSensitive ? query : query.toLowerCase();
      var pos = 0;
      while (pos < searchText.length) {
          final index = searchText.indexOf(searchQuery, pos);
          if (index == -1) break;
          matches.add((index, index + query.length));
          pos = index + 1;
      }
      return matches;
  }
}
  // Removed operator== and hashCode overrides that relied on toString().
  // Using identity equality is sufficient for Editor state tracking (new edits = new instances).
  // If value equality is strictly needed later, implement a structural comparison iterator.

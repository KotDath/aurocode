import 'text_summary.dart';
import 'leaf_node.dart';
import 'internal_node.dart';

/// Abstract base class for nodes in the B-Tree Rope.
abstract class RopeNode {
  /// The aggregated summary of this node (and its subtree).
  TextSummary get summary;

  /// Total length in characters.
  int get length => summary.length;

  /// Total number of lines.
  int get lineCount => summary.lines;
  
  /// Height of the node in the tree (0 for leaves).
  int get height;

  /// Creates a balanced RopeNode tree from [text].
  static RopeNode fromText(String text) {
     if (text.isEmpty) return LeafNode('');
     if (text.length <= kMaxLeafSize) return LeafNode(text);

     // 1. Chunkify
     final leaves = <RopeNode>[];
     for (var i = 0; i < text.length; i += kMaxLeafSize) {
         final end = (i + kMaxLeafSize).clamp(0, text.length);
         leaves.add(LeafNode(text.substring(i, end)));
     }

     // 2. Build Tree from bottom up
     return _buildTree(leaves);
  }

  static RopeNode _buildTree(List<RopeNode> nodes) {
      if (nodes.isEmpty) return LeafNode('');
      if (nodes.length == 1) return nodes[0];

      // Create a layer of parents
      final parents = <RopeNode>[];
      
      // Group nodes into chunks of kMaxChildren (8)
      // Since we want balance, we can fill them greedily?
      // Yes, standard usage.
      
      for (var i = 0; i < nodes.length; i += kMaxChildren) {
          final end = (i + kMaxChildren).clamp(0, nodes.length);
          final children = nodes.sublist(i, end);
          parents.add(InternalNode(children));
      }
      
      return _buildTree(parents);
  }

  /// Inserts [text] at [offset], returning a new node (or generic split list).
  List<RopeNode> insert(int offset, String text);

  /// Deletes range from [start] to [end].
  RopeNode? delete(int start, int end);

  /// Slices the node from [start] to [end].
  RopeNode slice(int start, int end);

  /// Returns the character at [index].
  String charAt(int index);

  /// Returns text content.
  String toText();

  /// Gets the line index at the given character [offset].
  int lineIndexAt(int offset);

  /// Gets the character offset where [lineIndex] starts.
  int lineStartOffset(int lineIndex);
  
  /// Concatenates this node with [other].
  RopeNode concat(RopeNode other);
}

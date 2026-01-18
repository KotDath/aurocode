import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurocode_ide/features/editor/domain/entities/rope.dart';

/// Property-based (fuzz) tests for Rope.
/// 
/// These tests generate random sequences of insert/delete operations
/// and verify that the Rope always matches a reference StringBuffer.
void main() {
  group('Rope Fuzz Tests', () {
    test('random insert/delete sequence (1000 operations)', () {
      final random = Random(42); // Fixed seed for reproducibility
      var rope = Rope.empty();
      var reference = StringBuffer();
      
      for (var i = 0; i < 1000; i++) {
        final operation = random.nextInt(10);
        
        if (operation < 6 || reference.isEmpty) {
          // Insert (60% chance, or 100% if empty)
          final text = _randomString(random, 1, 50);
          final position = reference.isEmpty ? 0 : random.nextInt(reference.length + 1);
          
          rope = rope.insert(position, text);
          final refStr = reference.toString();
          reference = StringBuffer(
            refStr.substring(0, position) + text + refStr.substring(position)
          );
        } else {
          // Delete (40% chance)
          final start = random.nextInt(reference.length);
          final maxLen = reference.length - start;
          final deleteLen = random.nextInt(maxLen) + 1;
          final end = start + deleteLen;
          
          rope = rope.delete(start, end);
          final refStr = reference.toString();
          reference = StringBuffer(
            refStr.substring(0, start) + refStr.substring(end)
          );
        }
        
        // Verify after each operation
        expect(
          rope.toString(), 
          reference.toString(),
          reason: 'Mismatch at operation $i',
        );
        expect(
          rope.length, 
          reference.length,
          reason: 'Length mismatch at operation $i',
        );
      }
    });

    test('random insert/delete with line verification (500 operations)', () {
      final random = Random(123);
      var rope = Rope.empty();
      var reference = StringBuffer();
      
      for (var i = 0; i < 500; i++) {
        final operation = random.nextInt(10);
        
        if (operation < 6 || reference.isEmpty) {
          // Insert - include newlines sometimes
          final includeNewlines = random.nextBool();
          final text = includeNewlines 
              ? _randomStringWithNewlines(random, 1, 30)
              : _randomString(random, 1, 30);
          final position = reference.isEmpty ? 0 : random.nextInt(reference.length + 1);
          
          rope = rope.insert(position, text);
          final refStr = reference.toString();
          reference = StringBuffer(
            refStr.substring(0, position) + text + refStr.substring(position)
          );
        } else {
          // Delete
          final start = random.nextInt(reference.length);
          final maxLen = reference.length - start;
          final deleteLen = random.nextInt(maxLen.clamp(1, 20)) + 1;
          final end = (start + deleteLen).clamp(0, reference.length);
          
          rope = rope.delete(start, end);
          final refStr = reference.toString();
          reference = StringBuffer(
            refStr.substring(0, start) + refStr.substring(end)
          );
        }
        
        // Verify content
        final ropeStr = rope.toString();
        final refStr = reference.toString();
        expect(ropeStr, refStr, reason: 'Content mismatch at operation $i');
        
        // Verify line count
        final expectedLines = refStr.isEmpty ? 0 : '\n'.allMatches(refStr).length + 1;
        expect(rope.lineCount, expectedLines, reason: 'Line count mismatch at operation $i');
      }
    });

    test('stress test: many small insertions', () {
      var rope = Rope.empty();
      const iterations = 5000;
      
      for (var i = 0; i < iterations; i++) {
        rope = rope.insert(rope.length, 'x');
      }
      
      expect(rope.length, iterations);
      expect(rope.toString(), 'x' * iterations);
    });

    test('stress test: insert at random positions', () {
      final random = Random(999);
      var rope = Rope.empty();
      var reference = StringBuffer();
      
      for (var i = 0; i < 1000; i++) {
        final char = String.fromCharCode(97 + random.nextInt(26));
        final position = reference.isEmpty ? 0 : random.nextInt(reference.length + 1);
        
        rope = rope.insert(position, char);
        final refStr = reference.toString();
        reference = StringBuffer(
          refStr.substring(0, position) + char + refStr.substring(position)
        );
      }
      
      expect(rope.toString(), reference.toString());
    });

    test('stress test: alternating insert/delete', () {
      final random = Random(456);
      var rope = Rope('Initial text for testing.');
      var reference = StringBuffer('Initial text for testing.');
      
      for (var i = 0; i < 500; i++) {
        if (i.isEven) {
          // Insert
          final text = _randomString(random, 1, 10);
          final position = random.nextInt(reference.length + 1);
          
          rope = rope.insert(position, text);
          final refStr = reference.toString();
          reference = StringBuffer(
            refStr.substring(0, position) + text + refStr.substring(position)
          );
        } else if (reference.isNotEmpty) {
          // Delete
          final start = random.nextInt(reference.length);
          final end = (start + random.nextInt(5) + 1).clamp(0, reference.length);
          
          rope = rope.delete(start, end);
          final refStr = reference.toString();
          reference = StringBuffer(
            refStr.substring(0, start) + refStr.substring(end)
          );
        }
      }
      
      expect(rope.toString(), reference.toString());
    });

    test('line operations consistency', () {
      final random = Random(789);
      var rope = Rope.empty();
      
      // Build a rope with lines
      for (var i = 0; i < 100; i++) {
        rope = rope.insert(rope.length, 'Line $i content here\n');
      }
      
      // Verify all lines are accessible
      for (var i = 0; i < rope.lineCount; i++) {
        final line = rope.getLine(i);
        final startOffset = rope.lineStartOffset(i);
        final lineAtOffset = rope.lineIndexAt(startOffset);
        
        expect(lineAtOffset, i, reason: 'lineIndexAt mismatch for line $i');
        expect(line.isNotEmpty || i == rope.lineCount - 1, true);
      }
    });
  });
}

String _randomString(Random random, int minLen, int maxLen) {
  final length = minLen + random.nextInt(maxLen - minLen + 1);
  return String.fromCharCodes(
    List.generate(length, (_) => 97 + random.nextInt(26)),
  );
}

String _randomStringWithNewlines(Random random, int minLen, int maxLen) {
  final length = minLen + random.nextInt(maxLen - minLen + 1);
  return String.fromCharCodes(
    List.generate(length, (_) {
      if (random.nextInt(10) == 0) return 10; // newline
      return 97 + random.nextInt(26);
    }),
  );
}

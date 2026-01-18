import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:aurocode_ide/features/editor/domain/entities/rope/rope.dart';

void main() {
  group('Rope Performance Benchmarks', () {
    // Generate a 10MB string
    // 10MB is large enough to stress test, but small enough to run quickly in generic CI.
    // 1MB = 1024 * 1024 chars approx.
    const int targetSize = 10 * 1024 * 1024; 
    late String largeText;

    setUpAll(() {
      final sw = Stopwatch()..start();
      print('Generating 10MB test string...');
      final buffer = StringBuffer();
      final line = "int main() { printf('Hello World'); return 0; }\n"; // ~50 chars
      while (buffer.length < targetSize) {
        buffer.write(line);
      }
      largeText = buffer.toString();
      print('Generated ${largeText.length} chars in ${sw.elapsedMilliseconds}ms');
    });

    test('Benchmark: Rope Creation (Bulk Load)', () {
      final sw = Stopwatch()..start();
      final rope = Rope(largeText);
      sw.stop();
      
      print('Rope(10MB) took: ${sw.elapsedMilliseconds}ms');
      expect(rope.length, largeText.length);
      
      // Sanity check: Should be faster than O(N^2). 
      // 10MB creation should be < 500ms on modern CPU (pure copy+allocation).
      expect(sw.elapsedMilliseconds, lessThan(2000)); 
    });

    test('Benchmark: Random Insertion', () {
      final rope = Rope(largeText);
      final random = Random(42);
      final sw = Stopwatch()..start();
      
      var currentRope = rope;
      const int operations = 1000;
      
      for (var i = 0; i < operations; i++) {
        final pos = random.nextInt(currentRope.length);
        currentRope = currentRope.insert(pos, "xyz");
      }
      
      sw.stop();
      print('$operations insertions took: ${sw.elapsedMilliseconds}ms');
      print('Average creation time per insert: ${sw.elapsedMilliseconds / operations}ms');
      
      // B-Tree insert should be O(log N).
      // 1000 inserts should be instant.
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('Benchmark: Random Deletion', () {
      final rope = Rope(largeText);
      final random = Random(42);
      final sw = Stopwatch()..start();
      
      var currentRope = rope;
      const int operations = 1000;
      
      for (var i = 0; i < operations; i++) {
        final pos = random.nextInt(currentRope.length - 100);
        currentRope = currentRope.delete(pos, pos + 5);
      }
      
      sw.stop();
      print('$operations deletions took: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
    
    test('Benchmark: Random Line Access (getLine)', () {
      final rope = Rope(largeText);
      final lineCount = rope.lineCount;
      final random = Random(42);
      final sw = Stopwatch()..start();
      
      const int operations = 10000;
      
      for (var i = 0; i < operations; i++) {
        final lineIndex = random.nextInt(lineCount);
        final _ = rope.getLine(lineIndex);
      }
      
      sw.stop();
      print('$operations getLine calls took: ${sw.elapsedMilliseconds}ms');
      print('Average time per getLine: ${(sw.elapsedMicroseconds / operations).toStringAsFixed(2)}µs');
      
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
    
     test('Benchmark: Random Line Index Lookup (lineIndexAt)', () {
      final rope = Rope(largeText);
      final len = rope.length;
      final random = Random(42);
      final sw = Stopwatch()..start();
      
      const int operations = 10000;
      
      for (var i = 0; i < operations; i++) {
        final offset = random.nextInt(len);
        final _ = rope.lineIndexAt(offset);
      }
      
      sw.stop();
      print('$operations lineIndexAt calls took: ${sw.elapsedMilliseconds}ms');
      
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}

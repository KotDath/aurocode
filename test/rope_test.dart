import 'package:flutter_test/flutter_test.dart';
import 'package:aurocode_ide/features/editor/domain/entities/rope.dart';

void main() {
  group('Rope - Basic Operations', () {
    test('empty rope has length 0 and lineCount 0', () {
      final rope = Rope.empty();
      expect(rope.length, 0);
      expect(rope.lineCount, 0);
      expect(rope.isEmpty, true);
      expect(rope.toString(), '');
    });

    test('rope from text preserves content', () {
      const text = 'Hello, World!';
      final rope = Rope(text);
      expect(rope.length, text.length);
      expect(rope.toString(), text);
    });

    test('insert at beginning', () {
      final rope = Rope('World');
      final result = rope.insert(0, 'Hello, ');
      expect(result.toString(), 'Hello, World');
      // Original unchanged
      expect(rope.toString(), 'World');
    });

    test('insert at end', () {
      final rope = Rope('Hello');
      final result = rope.insert(5, ', World!');
      expect(result.toString(), 'Hello, World!');
    });

    test('insert in middle', () {
      final rope = Rope('Helo');
      final result = rope.insert(2, 'l');
      expect(result.toString(), 'Hello');
    });

    test('delete from beginning', () {
      final rope = Rope('Hello, World');
      final result = rope.delete(0, 7);
      expect(result.toString(), 'World');
    });

    test('delete from end', () {
      final rope = Rope('Hello, World');
      final result = rope.delete(5, 12);
      expect(result.toString(), 'Hello');
    });

    test('delete from middle', () {
      final rope = Rope('Hello, World');
      final result = rope.delete(5, 7);
      expect(result.toString(), 'HelloWorld');
    });

    test('replace text', () {
      final rope = Rope('Hello, World');
      final result = rope.replace(7, 12, 'Dart');
      expect(result.toString(), 'Hello, Dart');
    });

    test('substring', () {
      final rope = Rope('Hello, World!');
      expect(rope.substring(0, 5), 'Hello');
      expect(rope.substring(7, 12), 'World');
      expect(rope.substring(0), 'Hello, World!');
    });

    test('charAt', () {
      final rope = Rope('Hello');
      expect(rope.charAt(0), 'H');
      expect(rope.charAt(4), 'o');
    });

    test('concat', () {
      final a = Rope('Hello, ');
      final b = Rope('World!');
      final result = a.concat(b);
      expect(result.toString(), 'Hello, World!');
    });

    test('split', () {
      final rope = Rope('Hello, World');
      final (left, right) = rope.split(7);
      expect(left.toString(), 'Hello, ');
      expect(right.toString(), 'World');
    });
  });

  group('Rope - Line Operations', () {
    test('single line has lineCount 1', () {
      final rope = Rope('Hello');
      expect(rope.lineCount, 1);
    });

    test('two lines have lineCount 2', () {
      final rope = Rope('Hello\nWorld');
      expect(rope.lineCount, 2);
    });

    test('trailing newline adds a line', () {
      final rope = Rope('Hello\n');
      expect(rope.lineCount, 2);
    });

    test('multiple lines', () {
      final rope = Rope('Line 1\nLine 2\nLine 3');
      expect(rope.lineCount, 3);
    });

    test('getLine returns correct content', () {
      final rope = Rope('Line 1\nLine 2\nLine 3');
      expect(rope.getLine(0), 'Line 1');
      expect(rope.getLine(1), 'Line 2');
      expect(rope.getLine(2), 'Line 3');
    });

    test('getLine strips trailing newline', () {
      final rope = Rope('Hello\nWorld\n');
      expect(rope.getLine(0), 'Hello');
      expect(rope.getLine(1), 'World');
      expect(rope.getLine(2), '');
    });

    test('lineIndexAt returns correct line', () {
      final rope = Rope('AB\nCD\nEF');
      expect(rope.lineIndexAt(0), 0); // A
      expect(rope.lineIndexAt(1), 0); // B
      expect(rope.lineIndexAt(2), 0); // \n
      expect(rope.lineIndexAt(3), 1); // C
      expect(rope.lineIndexAt(5), 1); // \n
      expect(rope.lineIndexAt(6), 2); // E
    });

    test('lineStartOffset returns correct offset', () {
      final rope = Rope('AB\nCD\nEF');
      expect(rope.lineStartOffset(0), 0);
      expect(rope.lineStartOffset(1), 3);
      expect(rope.lineStartOffset(2), 6);
    });

    test('lineEndOffset returns correct offset', () {
      final rope = Rope('AB\nCD\nEF');
      expect(rope.lineEndOffset(0), 3); // includes \n
      expect(rope.lineEndOffset(1), 6); // includes \n
      expect(rope.lineEndOffset(2), 8); // end of text
    });

    test('lines iterable', () {
      final rope = Rope('A\nB\nC');
      expect(rope.lines.toList(), ['A', 'B', 'C']);
    });
  });

  group('Rope - Edge Cases', () {
    test('insert empty string returns same rope', () {
      final rope = Rope('Hello');
      final result = rope.insert(0, '');
      expect(identical(result, rope), true);
    });

    test('delete zero-length range returns same rope', () {
      final rope = Rope('Hello');
      final result = rope.delete(2, 2);
      expect(identical(result, rope), true);
    });

    test('insert into empty rope', () {
      final rope = Rope.empty();
      final result = rope.insert(0, 'Hello');
      expect(result.toString(), 'Hello');
    });

    test('delete all content', () {
      final rope = Rope('Hello');
      final result = rope.delete(0, 5);
      expect(result.isEmpty, true);
      expect(result.toString(), '');
    });

    test('large text is split into leaves', () {
      final text = 'x' * 2000;
      final rope = Rope(text);
      expect(rope.length, 2000);
      expect(rope.toString(), text);
    });

    test('many insertions maintain correctness', () {
      var rope = Rope.empty();
      for (var i = 0; i < 100; i++) {
        rope = rope.insert(rope.length, 'line $i\n');
      }
      expect(rope.lineCount, 101); // 100 lines + empty line after last \n
    });

    test('equality manual', () {
      final a = Rope('Hello');
      final b = Rope('Hello');
      // final c = Rope('World');
      // expect(a == b, true); // Removed: Identity only now
      expect(a.toString(), b.toString());
    });
  });

  group('Rope - Error Handling', () {
    test('charAt throws on invalid index', () {
      final rope = Rope('Hello');
      expect(() => rope.charAt(-1), throwsRangeError);
      expect(() => rope.charAt(5), throwsRangeError);
    });

    test('insert throws on invalid position', () {
      final rope = Rope('Hello');
      expect(() => rope.insert(-1, 'x'), throwsRangeError);
      expect(() => rope.insert(6, 'x'), throwsRangeError);
    });

    test('delete throws on invalid range', () {
      final rope = Rope('Hello');
      expect(() => rope.delete(-1, 2), throwsRangeError);
      expect(() => rope.delete(0, 6), throwsRangeError);
      expect(() => rope.delete(3, 2), throwsRangeError);
    });

    test('getLine throws on invalid index', () {
      final rope = Rope('Hello\nWorld');
      expect(() => rope.getLine(-1), throwsRangeError);
      expect(() => rope.getLine(2), throwsRangeError);
    });
  });
}

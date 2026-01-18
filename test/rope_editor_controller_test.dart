import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurocode_ide/features/editor/application/rope_editor_controller.dart';

void main() {
  group('RopeEditorController - Basic Operations', () {
    test('initial state', () {
      final controller = RopeEditorController(initialText: 'Hello');
      expect(controller.text, 'Hello');
      expect(controller.length, 5);
      expect(controller.cursorOffset, 0);
      expect(controller.hasSelection, false);
    });

    test('insert text', () {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 5));
      controller.insertText(' World');
      expect(controller.text, 'Hello World');
      expect(controller.cursorOffset, 11);
    });

    test('insert at cursor', () {
      final controller = RopeEditorController(initialText: 'Hllo');
      controller.setSelection(const TextSelection.collapsed(offset: 1));
      controller.insertText('e');
      expect(controller.text, 'Hello');
      expect(controller.cursorOffset, 2);
    });

    test('delete backward (backspace)', () {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 5));
      controller.deleteBackward();
      expect(controller.text, 'Hell');
      expect(controller.cursorOffset, 4);
    });

    test('delete forward (delete key)', () {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 0));
      controller.deleteForward();
      expect(controller.text, 'ello');
      expect(controller.cursorOffset, 0);
    });

    test('delete selection', () {
      final controller = RopeEditorController(initialText: 'Hello World');
      controller.setSelection(const TextSelection(baseOffset: 0, extentOffset: 6));
      controller.deleteSelection();
      expect(controller.text, 'World');
      expect(controller.cursorOffset, 0);
    });

    test('replace selection', () {
      final controller = RopeEditorController(initialText: 'Hello World');
      controller.setSelection(const TextSelection(baseOffset: 6, extentOffset: 11));
      controller.replaceSelection('Dart');
      expect(controller.text, 'Hello Dart');
      expect(controller.cursorOffset, 10);
    });
  });

  group('RopeEditorController - Cursor Movement', () {
    test('move cursor left', () {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 3));
      controller.moveCursor(-1);
      expect(controller.cursorOffset, 2);
    });

    test('move cursor right', () {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 3));
      controller.moveCursor(1);
      expect(controller.cursorOffset, 4);
    });

    test('move cursor with extend (selection)', () {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 0));
      controller.moveCursor(3, extend: true);
      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 3);
      expect(controller.hasSelection, true);
    });

    test('move cursor to line start', () {
      final controller = RopeEditorController(initialText: 'Line 1\nLine 2');
      controller.setSelection(const TextSelection.collapsed(offset: 10));
      controller.moveCursorToLineStart();
      expect(controller.cursorOffset, 7); // Start of "Line 2"
    });

    test('move cursor to line end', () {
      final controller = RopeEditorController(initialText: 'Line 1\nLine 2');
      controller.setSelection(const TextSelection.collapsed(offset: 7));
      controller.moveCursorToLineEnd();
      expect(controller.cursorOffset, 13); // End of "Line 2"
    });

    test('move cursor up', () {
      final controller = RopeEditorController(initialText: 'Line 1\nLine 2');
      controller.setSelection(const TextSelection.collapsed(offset: 10)); // In "Line 2"
      controller.moveCursorUp();
      expect(controller.cursorOffset, 3); // Same column in "Line 1"
    });

    test('move cursor down', () {
      final controller = RopeEditorController(initialText: 'Line 1\nLine 2');
      controller.setSelection(const TextSelection.collapsed(offset: 3)); // In "Line 1"
      controller.moveCursorDown();
      expect(controller.cursorOffset, 10); // Same column in "Line 2"
    });

    test('select all', () {
      final controller = RopeEditorController(initialText: 'Hello World');
      controller.selectAll();
      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 11);
    });
  });

  group('RopeEditorController - Read-only Mode', () {
    test('insert text ignored in read-only', () {
      final controller = RopeEditorController(initialText: 'Hello', readOnly: true);
      controller.insertText(' World');
      expect(controller.text, 'Hello'); // Unchanged
    });

    test('delete ignored in read-only', () {
      final controller = RopeEditorController(initialText: 'Hello', readOnly: true);
      controller.setSelection(const TextSelection.collapsed(offset: 5));
      controller.deleteBackward();
      expect(controller.text, 'Hello'); // Unchanged
    });
  });

  group('RopeEditorController - Callbacks', () {
    test('onChanged is called on edits', () {
      String? changedText;
      final controller = RopeEditorController(
        initialText: 'Hello',
        onChanged: (rope) => changedText = rope.toString(),
      );
      controller.setSelection(const TextSelection.collapsed(offset: 5));
      controller.insertText('!');
      expect(changedText, 'Hello!');
    });
  });

  group('RopeEditorController - Undo/Redo', () {
    test('canUndo is false initially', () {
      final controller = RopeEditorController(initialText: 'Hello');
      expect(controller.canUndo, false);
      expect(controller.canRedo, false);
    });

    test('undo reverts insert', () async {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 5));
      controller.insertText('!');
      expect(controller.text, 'Hello!');
      expect(controller.canUndo, true);
      
      // Wait for coalesce timeout
      await Future.delayed(const Duration(milliseconds: 600));
      controller.insertText('!');
      expect(controller.text, 'Hello!!');
      
      controller.undo();
      expect(controller.text, 'Hello!');
      expect(controller.canRedo, true);
    });

    test('redo restores undone edit', () async {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 5));
      controller.insertText('!');
      
      await Future.delayed(const Duration(milliseconds: 600));
      controller.insertText('!');
      
      controller.undo();
      expect(controller.text, 'Hello!');
      
      controller.redo();
      expect(controller.text, 'Hello!!');
    });

    test('new edit clears redo stack', () async {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 5));
      controller.insertText('!');
      
      await Future.delayed(const Duration(milliseconds: 600));
      controller.insertText('!');
      
      controller.undo();
      expect(controller.canRedo, true);
      
      // New edit should clear redo
      await Future.delayed(const Duration(milliseconds: 600));
      controller.insertText('?');
      expect(controller.canRedo, false);
    });

    test('clearHistory clears both stacks', () async {
      final controller = RopeEditorController(initialText: 'Hello');
      controller.setSelection(const TextSelection.collapsed(offset: 5));
      controller.insertText('!');
      
      await Future.delayed(const Duration(milliseconds: 600));
      controller.insertText('!');
      
      controller.undo();
      expect(controller.canUndo, true);
      expect(controller.canRedo, true);
      
      controller.clearHistory();
      expect(controller.canUndo, false);
      expect(controller.canRedo, false);
    });
  });
}

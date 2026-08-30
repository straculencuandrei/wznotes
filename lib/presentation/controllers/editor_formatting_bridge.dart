import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditorFormattingBridge {
  TextEditingController? bodyController;
  FocusNode? bodyFocusNode;
  VoidCallback? onTextUpdated;

  void bind({
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onUpdate,
  }) {
    bodyController = controller;
    bodyFocusNode = focusNode;
    onTextUpdated = onUpdate;
  }

  void unbind() {
    bodyController = null;
    bodyFocusNode = null;
    onTextUpdated = null;
  }

  /// Wraps current selection or inserts wrapper symbols (e.g. **bold**, *italic*, ~~strike~~)
  void wrapSelection(String prefix, String suffix) {
    if (bodyController == null) return;
    final controller = bodyController!;
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      final int pos = selection.isValid && selection.baseOffset >= 0 ? selection.baseOffset : text.length;
      final newText = text.replaceRange(pos, pos, '$prefix$suffix');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + prefix.length),
      );
    } else {
      final selectedText = selection.textInside(text);
      // Toggle off if already wrapped
      if (selectedText.startsWith(prefix) && selectedText.endsWith(suffix) && selectedText.length >= prefix.length + suffix.length) {
        final unwrapped = selectedText.substring(prefix.length, selectedText.length - suffix.length);
        final newText = text.replaceRange(selection.start, selection.end, unwrapped);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(baseOffset: selection.start, extentOffset: selection.start + unwrapped.length),
        );
      } else {
        final wrapped = '$prefix$selectedText$suffix';
        final newText = text.replaceRange(selection.start, selection.end, wrapped);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(baseOffset: selection.start, extentOffset: selection.start + wrapped.length),
        );
      }
    }

    onTextUpdated?.call();
    bodyFocusNode?.requestFocus();
  }

  /// Toggles line prefix at current cursor line (e.g. "- ", "[ ] ", "> ")
  void toggleLinePrefix(String prefix) {
    if (bodyController == null) return;
    final controller = bodyController!;
    final text = controller.text;
    final selection = controller.selection;
    final int cursorIndex = selection.isValid && selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    // Find current line bounds
    int lineStart = 0;
    if (cursorIndex > 0 && cursorIndex <= text.length) {
      lineStart = text.lastIndexOf('\n', cursorIndex - 1);
      lineStart = lineStart == -1 ? 0 : lineStart + 1;
    }

    int lineEnd = text.indexOf('\n', cursorIndex);
    if (lineEnd == -1) lineEnd = text.length;

    final currentLine = text.substring(lineStart, lineEnd);

    if (currentLine.startsWith(prefix)) {
      // Remove prefix
      final updatedLine = currentLine.substring(prefix.length);
      final newText = text.replaceRange(lineStart, lineEnd, updatedLine);
      final newCursor = (cursorIndex - prefix.length).clamp(lineStart, newText.length);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    } else {
      // Add prefix
      final updatedLine = '$prefix$currentLine';
      final newText = text.replaceRange(lineStart, lineEnd, updatedLine);
      final newCursor = cursorIndex + prefix.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    onTextUpdated?.call();
    bodyFocusNode?.requestFocus();
  }
}

final editorFormattingBridgeProvider = Provider<EditorFormattingBridge>((ref) {
  return EditorFormattingBridge();
});

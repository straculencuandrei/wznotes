import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditorFormattingBridge extends ChangeNotifier {
  TextEditingController? bodyController;
  FocusNode? bodyFocusNode;
  VoidCallback? onTextUpdated;

  bool isBold = false;
  bool isItalic = false;
  bool isStrike = false;

  void bind({
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onUpdate,
  }) {
    bodyController = controller;
    bodyFocusNode = focusNode;
    onTextUpdated = onUpdate;
    controller.addListener(_syncActiveStyles);
  }

  void unbind() {
    bodyController?.removeListener(_syncActiveStyles);
    bodyController = null;
    bodyFocusNode = null;
    onTextUpdated = null;
  }

  void _syncActiveStyles() {
    if (bodyController == null) return;
    final text = bodyController!.text;
    final selection = bodyController!.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selected = selection.textInside(text);
      isBold = selected.startsWith('**') && selected.endsWith('**');
      isItalic = selected.startsWith('*') && selected.endsWith('*');
      isStrike = selected.startsWith('~~') && selected.endsWith('~~');
      notifyListeners();
    }
  }

  /// Toggles Bold formatting (**text**)
  void toggleBold() {
    isBold = !isBold;
    _applyWrapper('**', '**');
    notifyListeners();
  }

  /// Toggles Italic formatting (*text*)
  void toggleItalic() {
    isItalic = !isItalic;
    _applyWrapper('*', '*');
    notifyListeners();
  }

  /// Toggles Strikethrough (~~text~~)
  void toggleStrike() {
    isStrike = !isStrike;
    _applyWrapper('~~', '~~');
    notifyListeners();
  }

  void _applyWrapper(String prefix, String suffix) {
    if (bodyController == null) return;
    final controller = bodyController!;
    final text = controller.text;
    final selection = controller.selection;

    // Ensure focus is kept on editor
    bodyFocusNode?.requestFocus();

    if (!selection.isValid || selection.isCollapsed) {
      final int pos = selection.isValid && selection.baseOffset >= 0 ? selection.baseOffset : text.length;
      final newText = text.replaceRange(pos, pos, '$prefix$suffix');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + prefix.length),
      );
    } else {
      final selectedText = selection.textInside(text);
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
  }

  /// Toggles line prefix at current cursor line (e.g. "- ", "[ ] ", "> ")
  void toggleLinePrefix(String prefix) {
    if (bodyController == null) return;
    final controller = bodyController!;
    final text = controller.text;
    final selection = controller.selection;

    bodyFocusNode?.requestFocus();

    final int cursorIndex = selection.isValid && selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    int lineStart = 0;
    if (cursorIndex > 0 && cursorIndex <= text.length) {
      lineStart = text.lastIndexOf('\n', cursorIndex - 1);
      lineStart = lineStart == -1 ? 0 : lineStart + 1;
    }

    int lineEnd = text.indexOf('\n', cursorIndex);
    if (lineEnd == -1) lineEnd = text.length;

    final currentLine = text.substring(lineStart, lineEnd);

    if (currentLine.startsWith(prefix)) {
      final updatedLine = currentLine.substring(prefix.length);
      final newText = text.replaceRange(lineStart, lineEnd, updatedLine);
      final newCursor = (cursorIndex - prefix.length).clamp(lineStart, newText.length);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    } else {
      final updatedLine = '$prefix$currentLine';
      final newText = text.replaceRange(lineStart, lineEnd, updatedLine);
      final newCursor = cursorIndex + prefix.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    onTextUpdated?.call();
  }
}

final editorFormattingBridgeProvider = ChangeNotifierProvider<EditorFormattingBridge>((ref) {
  return EditorFormattingBridge();
});

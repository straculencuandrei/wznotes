import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'rich_span_editing_controller.dart';
import '../../core/diagnostics/performance_benchmark.dart';

class EditorFormattingBridge extends ChangeNotifier {
  RichSpanEditingController? bodyController;
  FocusNode? bodyFocusNode;
  VoidCallback? onTextUpdated;

  int chunkCount = 1;
  int activeChunkIndex = 0;
  int totalDocumentChars = 0;
  void Function(String fullText)? rechunkCallback;

  void bind({
    required RichSpanEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onUpdate,
    int chunkCount = 1,
    int activeChunkIndex = 0,
    int totalDocumentChars = 0,
    void Function(String fullText)? rechunkCallback,
  }) {
    bodyController = controller;
    bodyFocusNode = focusNode;
    onTextUpdated = onUpdate;
    this.chunkCount = chunkCount;
    this.activeChunkIndex = activeChunkIndex;
    this.totalDocumentChars = totalDocumentChars;
    this.rechunkCallback = rechunkCallback;
    _lastBold = isBold;
    _lastItalic = isItalic;
    _lastStrike = isStrike;
    controller.addListener(_syncActiveStyles);
  }

  void unbind() {
    bodyController?.removeListener(_syncActiveStyles);
    bodyController = null;
    bodyFocusNode = null;
    onTextUpdated = null;
    rechunkCallback = null;
  }

  void rechunk(String fullText) {
    rechunkCallback?.call(fullText);
  }

  bool _lastBold = false;
  bool _lastItalic = false;
  bool _lastStrike = false;

  bool get isBold => bodyController?.activeBold ?? false;
  bool get isItalic => bodyController?.activeItalic ?? false;
  bool get isStrike => bodyController?.activeStrike ?? false;

  void _syncActiveStyles() {
    PerformanceBenchmarkService.measure('bridge_sync_styles', () {
      final b = isBold;
      final i = isItalic;
      final s = isStrike;
      if (b != _lastBold || i != _lastItalic || s != _lastStrike) {
        _lastBold = b;
        _lastItalic = i;
        _lastStrike = s;
        notifyListeners();
      }
    });
  }

  /// Toggles Bold formatting in-place
  void toggleBold() {
    if (bodyController == null) return;
    bodyFocusNode?.requestFocus();
    bodyController!.toggleBold();
    onTextUpdated?.call();
    notifyListeners();
  }

  /// Toggles Italic formatting in-place
  void toggleItalic() {
    if (bodyController == null) return;
    bodyFocusNode?.requestFocus();
    bodyController!.toggleItalic();
    onTextUpdated?.call();
    notifyListeners();
  }

  /// Toggles Strikethrough in-place
  void toggleStrike() {
    if (bodyController == null) return;
    bodyFocusNode?.requestFocus();
    bodyController!.toggleStrike();
    onTextUpdated?.call();
    notifyListeners();
  }

  /// Toggles line prefix at current cursor line (e.g. "• ", "☐ ", "> ")
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
    notifyListeners();
  }
}

final editorFormattingBridgeProvider = ChangeNotifierProvider<EditorFormattingBridge>((ref) {
  return EditorFormattingBridge();
});

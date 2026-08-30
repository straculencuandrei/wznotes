import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/text_block.dart';
import '../../domain/models/text_span_node.dart';
import 'document_controller.dart';

class TextEditorState {
  final String? activeBlockId;
  final bool isToolbarVisible;

  const TextEditorState({
    this.activeBlockId,
    this.isToolbarVisible = false,
  });

  TextEditorState copyWith({
    String? activeBlockId,
    bool? isToolbarVisible,
    bool clearActiveBlock = false,
  }) {
    return TextEditorState(
      activeBlockId: clearActiveBlock ? null : (activeBlockId ?? this.activeBlockId),
      isToolbarVisible: isToolbarVisible ?? this.isToolbarVisible,
    );
  }
}

class TextEditorNotifier extends StateNotifier<TextEditorState> {
  final Ref ref;

  TextEditorNotifier(this.ref) : super(const TextEditorState());

  void setActiveBlock(String? blockId) {
    state = state.copyWith(activeBlockId: blockId, isToolbarVisible: blockId != null);
  }

  /// Processes text input and automatically detects markdown syntax shortcuts at the start of a block
  void handleTextInput(String blockId, String newText) {
    TextBlockType newType = TextBlockType.paragraph;
    String cleanText = newText;
    bool isChecked = false;
    String? codeLang;

    // Markdown Shortcut Detectors:
    if (newText.startsWith('# ')) {
      newType = TextBlockType.heading1;
      cleanText = newText.substring(2);
    } else if (newText.startsWith('## ')) {
      newType = TextBlockType.heading2;
      cleanText = newText.substring(3);
    } else if (newText.startsWith('### ')) {
      newType = TextBlockType.heading3;
      cleanText = newText.substring(4);
    } else if (newText.startsWith('- ') || newText.startsWith('* ')) {
      newType = TextBlockType.bulletList;
      cleanText = newText.substring(2);
    } else if (RegExp(r'^\d+\.\s').hasMatch(newText)) {
      newType = TextBlockType.numberedList;
      cleanText = newText.replaceFirst(RegExp(r'^\d+\.\s'), '');
    } else if (newText.startsWith('[] ') || newText.startsWith('[ ] ')) {
      newType = TextBlockType.checklist;
      cleanText = newText.startsWith('[ ] ') ? newText.substring(4) : newText.substring(3);
    } else if (newText.startsWith('[x] ')) {
      newType = TextBlockType.checklist;
      isChecked = true;
      cleanText = newText.substring(4);
    } else if (newText.startsWith('> ')) {
      newType = TextBlockType.blockquote;
      cleanText = newText.substring(2);
    } else if (newText.startsWith('```')) {
      newType = TextBlockType.codeBlock;
      final match = RegExp(r'^```(\w*)\n?').firstMatch(newText);
      codeLang = match?.group(1);
      cleanText = newText.replaceFirst(RegExp(r'^```\w*\n?'), '');
    }

    final double estimatedHeight = _calculateHeight(newType, cleanText);

    final updatedBlock = TextBlock(
      id: blockId,
      type: newType,
      rawText: cleanText,
      spans: [TextSpanNode(text: cleanText)],
      isChecked: isChecked,
      codeLanguage: codeLang,
      estimatedHeight: estimatedHeight,
    );

    ref.read(documentProvider.notifier).updateBlock(blockId, updatedBlock);
  }

  /// Inserts a new empty block below the current one on 'Enter' key
  void insertNewBlockAfter(String currentBlockId) {
    final doc = ref.read(documentProvider);
    final int index = doc.blocks.indexWhere((b) => b.id == currentBlockId);
    final newId = const Uuid().v4();

    final newBlock = TextBlock(
      id: newId,
      type: TextBlockType.paragraph,
      rawText: '',
      estimatedHeight: 32.0,
    );

    ref.read(documentProvider.notifier).addBlock(newBlock, index: index >= 0 ? index + 1 : null);
    setActiveBlock(newId);
  }

  static double _calculateHeight(TextBlockType type, String text) {
    switch (type) {
      case TextBlockType.heading1:
        return 48.0;
      case TextBlockType.heading2:
        return 38.0;
      case TextBlockType.heading3:
        return 32.0;
      case TextBlockType.codeBlock:
        final lines = text.split('\n').length;
        return (lines * 18.0) + 32.0;
      default:
        final lines = (text.length / 60).ceil().clamp(1, 20);
        return lines * 28.0;
    }
  }
}

final textEditorProvider = StateNotifierProvider<TextEditorNotifier, TextEditorState>((ref) {
  return TextEditorNotifier(ref);
});

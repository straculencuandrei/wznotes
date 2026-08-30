import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/text_block.dart';
import '../controllers/document_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/editor_formatting_bridge.dart';
import '../controllers/markdown_rich_text_controller.dart';
import 'vscode_smooth_text_field.dart';

/// Ultra-Fast Seamless AMOLED Note Writing Layer with Real WYSIWYG Bold/Italic and VSCode Smooth Caret
class InfiniteRichTextLayer extends ConsumerStatefulWidget {
  final double width;

  const InfiniteRichTextLayer({
    super.key,
    required this.width,
  });

  @override
  ConsumerState<InfiniteRichTextLayer> createState() => _InfiniteRichTextLayerState();
}

class _InfiniteRichTextLayerState extends ConsumerState<InfiniteRichTextLayer> {
  late TextEditingController _titleController;
  late MarkdownRichTextController _bodyController;
  late FocusNode _titleFocusNode;
  late FocusNode _bodyFocusNode;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final doc = ref.read(documentProvider);
    final settings = ref.read(settingsProvider);

    _titleController = TextEditingController(text: doc.metadata.title);
    _titleFocusNode = FocusNode();

    final initialBody = doc.blocks.map((b) => _blockToMarkdown(b)).join('\n');
    final bodyStyle = TextStyle(
      fontSize: settings.fontSize,
      height: 1.6,
      color: AppColors.amoledTextPrimary,
      fontFamily: 'Inter',
      letterSpacing: 0.2,
    );

    // WYSIWYG In-Place Markdown Controller (Direct Bold, Italic, Strikethrough, and Bullets)
    _bodyController = MarkdownRichTextController(
      text: initialBody,
      baseStyle: bodyStyle,
    );
    _bodyFocusNode = FocusNode();

    // Bind formatting bridge for instant toolbar actions
    ref.read(editorFormattingBridgeProvider).bind(
      controller: _bodyController,
      focusNode: _bodyFocusNode,
      onUpdate: () => _onBodyChanged(_bodyController.text),
    );
  }

  @override
  void dispose() {
    ref.read(editorFormattingBridgeProvider).unbind();
    _debounceTimer?.cancel();
    _flushSync();
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  String _blockToMarkdown(TextBlock b) {
    switch (b.type) {
      case TextBlockType.heading1:
        return '# ${b.rawText}';
      case TextBlockType.heading2:
        return '## ${b.rawText}';
      case TextBlockType.heading3:
        return '### ${b.rawText}';
      case TextBlockType.bulletList:
        return '- ${b.rawText}';
      case TextBlockType.checklist:
        return b.isChecked ? '[x] ${b.rawText}' : '[ ] ${b.rawText}';
      case TextBlockType.blockquote:
        return '> ${b.rawText}';
      case TextBlockType.codeBlock:
        return '```\n${b.rawText}\n```';
      default:
        return b.rawText;
    }
  }

  void _onBodyChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _flushSync();
    });
  }

  void _flushSync() {
    final text = _bodyController.text;
    final lines = text.split('\n');
    final List<TextBlock> updatedBlocks = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final id = 'block_$i';

      if (line.startsWith('# ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.heading1, rawText: line.substring(2)));
      } else if (line.startsWith('## ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.heading2, rawText: line.substring(3)));
      } else if (line.startsWith('### ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.heading3, rawText: line.substring(4)));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.bulletList, rawText: line.substring(2)));
      } else if (line.startsWith('[ ] ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.checklist, rawText: line.substring(4), isChecked: false));
      } else if (line.startsWith('[x] ') || line.startsWith('[X] ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.checklist, rawText: line.substring(4), isChecked: true));
      } else if (line.startsWith('> ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.blockquote, rawText: line.substring(2)));
      } else {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.paragraph, rawText: line));
      }
    }

    if (mounted) {
      final currentDoc = ref.read(documentProvider);
      ref.read(documentProvider.notifier).state = currentDoc.copyWith(
        metadata: currentDoc.metadata.copyWith(title: _titleController.text),
        blocks: updatedBlocks,
      ).recalculateStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    final titleStyle = const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w900,
      color: AppColors.amoledTextPrimary,
      letterSpacing: -0.6,
    );

    final bodyStyle = TextStyle(
      fontSize: settings.fontSize,
      height: 1.6,
      color: AppColors.amoledTextPrimary,
      fontFamily: 'Inter',
      letterSpacing: 0.2,
    );

    _bodyController.baseStyle = bodyStyle;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_bodyFocusNode.hasFocus && !_titleFocusNode.hasFocus) {
          _bodyFocusNode.requestFocus();
          _bodyController.selection = TextSelection.collapsed(offset: _bodyController.text.length);
        }
      },
      child: Container(
        width: widget.width,
        color: AppColors.amoledBlack,
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 250.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Note Title with VSCode Smooth Caret
            if (settings.smoothCaretEnabled)
              VSCodeSmoothTextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                style: titleStyle,
                hintText: 'Title',
                hintStyle: const TextStyle(
                  color: Color(0xFF404040),
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (val) => _onBodyChanged(_bodyController.text),
              )
            else
              TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                style: titleStyle,
                cursorColor: const Color(0xFFFF9100),
                cursorWidth: 2.4,
                cursorHeight: 32.0,
                cursorRadius: const Radius.circular(2.0),
                cursorOpacityAnimates: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Title',
                  hintStyle: TextStyle(
                    color: Color(0xFF404040),
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) => _onBodyChanged(_bodyController.text),
              ),

            const SizedBox(height: 14),

            // 2. Infinite Body Text Editor with WYSIWYG In-Place Formatting & VSCode Smooth Caret
            if (settings.smoothCaretEnabled)
              VSCodeSmoothTextField(
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                style: bodyStyle,
                hintText: 'Write your thoughts, ideas, or journal...',
                hintStyle: TextStyle(
                  color: const Color(0xFF383838),
                  fontSize: settings.fontSize,
                ),
                onChanged: _onBodyChanged,
              )
            else
              TextField(
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: const Color(0xFFFF9100),
                cursorWidth: 2.4,
                cursorHeight: settings.fontSize * 1.25,
                cursorRadius: const Radius.circular(2.0),
                cursorOpacityAnimates: true,
                style: bodyStyle,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Write your thoughts, ideas, or journal...',
                  hintStyle: TextStyle(
                    color: const Color(0xFF383838),
                    fontSize: settings.fontSize,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _onBodyChanged,
              ),
          ],
        ),
      ),
    );
  }
}

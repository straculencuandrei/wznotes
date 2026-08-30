import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/text_block.dart';
import '../controllers/document_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/editor_formatting_bridge.dart';
import '../controllers/rich_span_editing_controller.dart';
import 'vscode_smooth_text_field.dart';

/// Ultra-Fast Seamless AMOLED Note Writing Layer with Pure Native Span Formatting & VS Code Smooth Caret
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
  late RichSpanEditingController _bodyController;
  late FocusNode _titleFocusNode;
  late FocusNode _bodyFocusNode;
  late EditorFormattingBridge _formattingBridge;
  late DocumentNotifier _docNotifier;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final doc = ref.read(documentProvider);
    final settings = ref.read(settingsProvider);
    _formattingBridge = ref.read(editorFormattingBridgeProvider);
    _docNotifier = ref.read(documentProvider.notifier);

    _titleController = TextEditingController(text: doc.metadata.title);
    _titleFocusNode = FocusNode();

    final bodyStyle = TextStyle(
      fontSize: settings.fontSize,
      height: 1.6,
      color: AppColors.amoledTextPrimary,
      fontFamily: 'Inter',
      letterSpacing: 0.2,
    );

    // Build plain text and restore exact formatting spans
    final buffer = StringBuffer();
    final List<FormattingSpan> initialSpans = [];

    for (int i = 0; i < doc.blocks.length; i++) {
      final b = doc.blocks[i];
      final prefix = _getBlockPrefix(b);
      buffer.write(prefix);

      if (b.spans.isNotEmpty) {
        int spanOffset = buffer.length;
        for (final s in b.spans) {
          final spanStart = spanOffset;
          final spanEnd = spanOffset + s.text.length;
          if (s.bold || s.italic || s.strikethrough) {
            initialSpans.add(FormattingSpan(
              start: spanStart,
              end: spanEnd,
              isBold: s.bold,
              isItalic: s.italic,
              isStrike: s.strikethrough,
            ));
          }
          spanOffset = spanEnd;
        }
        buffer.write(b.rawText);
      } else {
        buffer.write(b.rawText);
      }

      if (i < doc.blocks.length - 1) {
        buffer.write('\n');
      }
    }

    _bodyController = RichSpanEditingController(
      initialText: buffer.toString(),
      initialSpans: initialSpans,
      baseStyle: bodyStyle,
    );
    _bodyFocusNode = FocusNode();

    // Bind formatting bridge for instant toolbar actions
    _formattingBridge.bind(
      controller: _bodyController,
      focusNode: _bodyFocusNode,
      onUpdate: () => _onBodyChanged(_bodyController.text),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _formattingBridge.unbind();
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  String _getBlockPrefix(TextBlock b) {
    switch (b.type) {
      case TextBlockType.heading1:
        return '# ';
      case TextBlockType.heading2:
        return '## ';
      case TextBlockType.heading3:
        return '### ';
      case TextBlockType.bulletList:
        return '- ';
      case TextBlockType.checklist:
        return b.isChecked ? '[x] ' : '[ ] ';
      case TextBlockType.blockquote:
        return '> ';
      default:
        return '';
    }
  }

  void _onBodyChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 60), () {
      _flushSync();
    });
  }

  void _flushSync() {
    final text = _bodyController.text;
    final lines = text.split('\n');
    final List<TextBlock> updatedBlocks = [];
    int currentOffset = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final id = 'block_$i';
      final lineStart = currentOffset;
      final lineEnd = currentOffset + line.length;
      currentOffset = lineEnd + 1;

      final lineSpans = _bodyController.exportSpansForRange(lineStart, lineEnd);

      if (line.startsWith('# ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.heading1, rawText: line.substring(2), spans: lineSpans));
      } else if (line.startsWith('## ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.heading2, rawText: line.substring(3), spans: lineSpans));
      } else if (line.startsWith('### ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.heading3, rawText: line.substring(4), spans: lineSpans));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.bulletList, rawText: line.substring(2), spans: lineSpans));
      } else if (line.startsWith('[ ] ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.checklist, rawText: line.substring(4), isChecked: false, spans: lineSpans));
      } else if (line.startsWith('[x] ') || line.startsWith('[X] ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.checklist, rawText: line.substring(4), isChecked: true, spans: lineSpans));
      } else if (line.startsWith('> ')) {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.blockquote, rawText: line.substring(2), spans: lineSpans));
      } else {
        updatedBlocks.add(TextBlock(id: id, type: TextBlockType.paragraph, rawText: line, spans: lineSpans));
      }
    }

    _docNotifier.updateContent(
      title: _titleController.text,
      blocks: updatedBlocks,
    );
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

    return Container(
      width: widget.width,
      color: AppColors.amoledBlack,
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 250.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Note Title (VS Code Smooth Caret Animation)
          VSCodeSmoothTextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            style: titleStyle,
            hintText: 'Title',
            hintStyle: const TextStyle(
              color: Color(0xFF6E6E6E),
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (val) => _onBodyChanged(_bodyController.text),
          ),

          const SizedBox(height: 14),

          // 2. Infinite Body Text Editor (VS Code Smooth Caret Animation)
          VSCodeSmoothTextField(
            controller: _bodyController,
            focusNode: _bodyFocusNode,
            style: bodyStyle,
            hintText: 'Write your thoughts, ideas, or journal...',
            hintStyle: TextStyle(
              color: const Color(0xFF5A5A5A),
              fontSize: settings.fontSize,
            ),
            onChanged: _onBodyChanged,
          ),
        ],
      ),
    );
  }
}

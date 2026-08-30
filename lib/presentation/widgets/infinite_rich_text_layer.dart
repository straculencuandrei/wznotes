import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/text_block.dart';
import '../controllers/document_controller.dart';
import '../controllers/text_editor_controller.dart';

/// Pure AMOLED Keyboard-First Rich Text Writing Layer
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
  final FocusNode _firstBlockFocus = FocusNode();

  @override
  void dispose() {
    _firstBlockFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(documentProvider);

    return Container(
      width: widget.width,
      color: AppColors.amoledBlack,
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 300.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Clean AMOLED Note Title Field
          TextField(
            controller: TextEditingController(text: doc.metadata.title)
              ..selection = TextSelection.collapsed(offset: doc.metadata.title.length),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.amoledTextPrimary,
              letterSpacing: -0.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Title',
              hintStyle: TextStyle(
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.w700,
                fontSize: 30,
              ),
            ),
            onChanged: (val) => ref.read(documentProvider.notifier).setTitle(val),
          ),
          const SizedBox(height: 12),

          // 2. Text Blocks (Headings, Paragraphs, Checklists, Bullet Lists)
          ...doc.blocks.map((block) {
            return _buildBlockWidget(context, ref, block);
          }),

          // 3. Tap anywhere in empty space below to add text / focus
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (doc.blocks.isNotEmpty) {
                ref.read(textEditorProvider.notifier).insertNewBlockAfter(doc.blocks.last.id);
              }
            },
            child: Container(
              height: 350,
              width: double.infinity,
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockWidget(BuildContext context, WidgetRef ref, TextBlock block) {
    TextStyle style = const TextStyle(
      fontSize: 17.0,
      height: 1.6,
      color: AppColors.amoledTextPrimary,
      fontFamily: 'Inter',
    );

    if (block.type == TextBlockType.heading1) {
      style = style.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.samsungOrange,
      );
    } else if (block.type == TextBlockType.heading2) {
      style = style.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFE0E0E0),
      );
    } else if (block.type == TextBlockType.heading3) {
      style = style.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFBDBDBD),
      );
    }

    if (block.type == TextBlockType.checklist) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.scale(
              scale: 1.15,
              child: Checkbox(
                value: block.isChecked,
                onChanged: (_) => ref.read(documentProvider.notifier).toggleChecklist(block.id),
                activeColor: AppColors.samsungOrange,
                checkColor: Colors.black,
                side: const BorderSide(color: Color(0xFF666666), width: 1.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildEditableTextField(
                ref,
                block,
                style.copyWith(
                  decoration: block.isChecked ? TextDecoration.lineThrough : null,
                  color: block.isChecked ? const Color(0xFF555555) : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block.type == TextBlockType.bulletList) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 10.0, top: 4.0),
              child: Text(
                '•',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.samsungOrange,
                ),
              ),
            ),
            Expanded(child: _buildEditableTextField(ref, block, style)),
          ],
        ),
      );
    }

    if (block.type == TextBlockType.codeBlock) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF282828)),
        ),
        child: _buildEditableTextField(
          ref,
          block,
          const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF00E676),
          ),
        ),
      );
    }

    if (block.type == TextBlockType.blockquote) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.only(left: 14.0, top: 4.0, bottom: 4.0),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.samsungOrange, width: 3.5)),
        ),
        child: _buildEditableTextField(
          ref,
          block,
          style.copyWith(
            fontStyle: FontStyle.italic,
            color: const Color(0xFFAAAAAA),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: _buildEditableTextField(ref, block, style),
    );
  }

  Widget _buildEditableTextField(WidgetRef ref, TextBlock block, TextStyle style) {
    return TextFormField(
      key: ValueKey(block.id),
      initialValue: block.rawText,
      style: style,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 4),
        border: InputBorder.none,
        hintText: 'Start writing...',
        hintStyle: TextStyle(color: Color(0xFF333333), fontSize: 16),
      ),
      onChanged: (val) {
        ref.read(textEditorProvider.notifier).handleTextInput(block.id, val);
      },
      onTap: () {
        ref.read(textEditorProvider.notifier).setActiveBlock(block.id);
      },
    );
  }
}

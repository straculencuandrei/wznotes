import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/text_block.dart';
import '../controllers/document_controller.dart';
import '../controllers/text_editor_controller.dart';
import '../controllers/inking_controller.dart';

/// Clean Samsung Notes Style Bottom Keyboard Formatting Bar
class TextFormattingToolbar extends ConsumerWidget {
  const TextFormattingToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(textEditorProvider);
    final inkingState = ref.watch(inkingProvider);
    final inkingNotifier = ref.read(inkingProvider.notifier);
    final docNotifier = ref.read(documentProvider.notifier);
    final doc = ref.watch(documentProvider);

    final TextBlock? activeBlock = editorState.activeBlockId != null
        ? doc.blocks.firstWhere(
            (b) => b.id == editorState.activeBlockId,
            orElse: () => const TextBlock(id: '', type: TextBlockType.paragraph, rawText: ''),
          )
        : (doc.blocks.isNotEmpty ? doc.blocks.last : null);

    final currentType = activeBlock?.type ?? TextBlockType.paragraph;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.amoledSurface,
        border: Border(top: BorderSide(color: AppColors.amoledBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // 1. Bullet List
              _buildIconBtn(
                icon: Icons.format_list_bulleted,
                isSelected: currentType == TextBlockType.bulletList,
                onTap: () => _toggleType(ref, activeBlock, TextBlockType.bulletList),
              ),

              // 4. Checklist
              _buildIconBtn(
                icon: Icons.checklist_rtl,
                isSelected: currentType == TextBlockType.checklist,
                onTap: () => _toggleType(ref, activeBlock, TextBlockType.checklist),
              ),

              // 5. Quote
              _buildIconBtn(
                icon: Icons.format_quote,
                isSelected: currentType == TextBlockType.blockquote,
                onTap: () => _toggleType(ref, activeBlock, TextBlockType.blockquote),
              ),

              // 6. Code Block
              _buildIconBtn(
                icon: Icons.code,
                isSelected: currentType == TextBlockType.codeBlock,
                onTap: () => _toggleType(ref, activeBlock, TextBlockType.codeBlock),
              ),

              Container(
                width: 1,
                height: 24,
                color: AppColors.amoledBorder,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),

              // 7. Toggle Drawing / Inking Mode
              _buildIconBtn(
                icon: inkingState.isInkingMode ? Icons.edit : Icons.draw_outlined,
                isSelected: inkingState.isInkingMode,
                activeColor: AppColors.primaryBlue,
                onTap: () => inkingNotifier.toggleInkingMode(!inkingState.isInkingMode),
              ),

              // 8. Undo / Redo
              IconButton(
                icon: const Icon(Icons.undo, size: 20, color: Colors.white70),
                onPressed: docNotifier.canUndo ? () => docNotifier.undo() : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo, size: 20, color: Colors.white70),
                onPressed: docNotifier.canRedo ? () => docNotifier.redo() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleType(WidgetRef ref, TextBlock? block, TextBlockType type) {
    if (block == null || block.id.isEmpty) return;
    final newType = block.type == type ? TextBlockType.paragraph : type;
    ref.read(documentProvider.notifier).updateBlock(
          block.id,
          block.copyWith(type: newType),
        );
  }

  Widget _buildBtn({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.samsungOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn({
    required IconData icon,
    required bool isSelected,
    Color activeColor = AppColors.samsungOrange,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

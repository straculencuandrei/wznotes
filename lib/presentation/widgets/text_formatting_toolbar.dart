import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/text_block.dart';
import '../controllers/document_controller.dart';
import '../controllers/text_editor_controller.dart';
import '../controllers/inking_controller.dart';

/// Clean Samsung Notes Style Bottom Keyboard Formatting Bar
/// Evenly scaled across the full screen width
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.amoledSurface,
        border: Border(top: BorderSide(color: AppColors.amoledBorder, width: 1.2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. Bullet List
            _buildIconBtn(
              icon: Icons.format_list_bulleted,
              tooltip: 'Bullet List',
              isSelected: currentType == TextBlockType.bulletList,
              onTap: () => _toggleType(ref, activeBlock, TextBlockType.bulletList),
            ),

            // 2. Interactive Checklist
            _buildIconBtn(
              icon: Icons.checklist_rtl,
              tooltip: 'Checklist',
              isSelected: currentType == TextBlockType.checklist,
              onTap: () => _toggleType(ref, activeBlock, TextBlockType.checklist),
            ),

            // 3. Blockquote
            _buildIconBtn(
              icon: Icons.format_quote,
              tooltip: 'Quote',
              isSelected: currentType == TextBlockType.blockquote,
              onTap: () => _toggleType(ref, activeBlock, TextBlockType.blockquote),
            ),

            // 4. Code Block
            _buildIconBtn(
              icon: Icons.code,
              tooltip: 'Code Block',
              isSelected: currentType == TextBlockType.codeBlock,
              onTap: () => _toggleType(ref, activeBlock, TextBlockType.codeBlock),
            ),

            // Divider
            Container(
              width: 1.2,
              height: 26,
              color: AppColors.amoledBorder,
            ),

            // 5. Toggle Stylus / Drawing Mode
            _buildIconBtn(
              icon: inkingState.isInkingMode ? Icons.edit : Icons.draw_outlined,
              tooltip: inkingState.isInkingMode ? 'Switch to Typing' : 'Handwriting / Drawing Mode',
              isSelected: inkingState.isInkingMode,
              activeColor: AppColors.primaryBlue,
              onTap: () => inkingNotifier.toggleInkingMode(!inkingState.isInkingMode),
            ),

            // 6. Undo
            _buildIconBtn(
              icon: Icons.undo,
              tooltip: 'Undo',
              isSelected: false,
              isEnabled: docNotifier.canUndo,
              onTap: docNotifier.canUndo ? () => docNotifier.undo() : () {},
            ),

            // 7. Redo
            _buildIconBtn(
              icon: Icons.redo,
              tooltip: 'Redo',
              isSelected: false,
              isEnabled: docNotifier.canRedo,
              onTap: docNotifier.canRedo ? () => docNotifier.redo() : () {},
            ),
          ],
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

  Widget _buildIconBtn({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    bool isEnabled = true,
    Color activeColor = AppColors.samsungOrange,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isSelected
                  ? Colors.black
                  : (isEnabled ? Colors.white : Colors.white24),
            ),
          ),
        ),
      ),
    );
  }
}

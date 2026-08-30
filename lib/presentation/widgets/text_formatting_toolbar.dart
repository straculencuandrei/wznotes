import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/document_controller.dart';
import '../controllers/inking_controller.dart';
import '../controllers/editor_formatting_bridge.dart';

/// Samsung Notes Style Floating Island Formatting Toolbar
/// Centered floating pill with active states, focus retention, and instant in-place formatting
class TextFormattingToolbar extends ConsumerWidget {
  const TextFormattingToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inkingState = ref.watch(inkingProvider);
    final inkingNotifier = ref.read(inkingProvider.notifier);
    final docNotifier = ref.read(documentProvider.notifier);
    final bridge = ref.watch(editorFormattingBridgeProvider);

    return FocusScope(
      canRequestFocus: false, // Prevents toolbar from stealing focus from text field & keyboard
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10, top: 4),
        child: SafeArea(
          top: false,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF2C2C2C), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. Bold (B)
                  _buildIslandBtn(
                    icon: Icons.format_bold_rounded,
                    tooltip: 'Bold',
                    isSelected: bridge.isBold,
                    onTap: () => bridge.toggleBold(),
                  ),

                  // 2. Italic (I)
                  _buildIslandBtn(
                    icon: Icons.format_italic_rounded,
                    tooltip: 'Italic',
                    isSelected: bridge.isItalic,
                    onTap: () => bridge.toggleItalic(),
                  ),

                  // 3. Strikethrough (S)
                  _buildIslandBtn(
                    icon: Icons.strikethrough_s_rounded,
                    tooltip: 'Strikethrough',
                    isSelected: bridge.isStrike,
                    onTap: () => bridge.toggleStrike(),
                  ),

                  // Divider
                  Container(
                    width: 1.2,
                    height: 22,
                    color: const Color(0xFF2E2E2E),
                  ),

                  // 4. Bullet List (•)
                  _buildIslandBtn(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: 'Bullet List',
                    onTap: () => bridge.toggleLinePrefix('- '),
                  ),

                  // 5. Interactive Checklist (☑)
                  _buildIslandBtn(
                    icon: Icons.checklist_rtl_rounded,
                    tooltip: 'Checklist',
                    onTap: () => bridge.toggleLinePrefix('[ ] '),
                  ),

                  // 6. Blockquote (”)
                  _buildIslandBtn(
                    icon: Icons.format_quote_rounded,
                    tooltip: 'Quote',
                    onTap: () => bridge.toggleLinePrefix('> '),
                  ),

                  // Divider
                  Container(
                    width: 1.2,
                    height: 22,
                    color: const Color(0xFF2E2E2E),
                  ),

                  // 7. Handwriting / Drawing Toggle
                  _buildIslandBtn(
                    icon: inkingState.isInkingMode ? Icons.edit_rounded : Icons.draw_outlined,
                    tooltip: inkingState.isInkingMode ? 'Switch to Typing' : 'Handwriting / Drawing',
                    isSelected: inkingState.isInkingMode,
                    activeColor: AppColors.primaryBlue,
                    onTap: () => inkingNotifier.toggleInkingMode(!inkingState.isInkingMode),
                  ),

                  // 8. Undo
                  _buildIslandBtn(
                    icon: Icons.undo_rounded,
                    tooltip: 'Undo',
                    isEnabled: docNotifier.canUndo,
                    onTap: docNotifier.canUndo ? () => docNotifier.undo() : () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIslandBtn({
    required IconData icon,
    required String tooltip,
    bool isSelected = false,
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/pen_tool.dart';
import '../controllers/inking_controller.dart';
import '../controllers/document_controller.dart';

/// Modern floating stylus dock with tool selector, color palette, and thickness slider
/// Fully responsive with horizontal scrolling to prevent any screen overflow
class FloatingPenDock extends ConsumerWidget {
  const FloatingPenDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inkingState = ref.watch(inkingProvider);
    final inkingNotifier = ref.read(inkingProvider.notifier);
    final docNotifier = ref.read(documentProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTool = inkingState.toolConfig.type;

    return Card(
      elevation: 10,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.amoledSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.amoledBorder : AppColors.lightBorder,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Inking / Typing Mode Toggle
              IconButton(
                icon: Icon(
                  inkingState.isInkingMode ? Icons.edit : Icons.keyboard,
                  color: AppColors.samsungOrange,
                  size: 20,
                ),
                tooltip: inkingState.isInkingMode ? 'Switch to Typing' : 'Switch to Inking',
                onPressed: () => inkingNotifier.toggleInkingMode(!inkingState.isInkingMode),
              ),
              Container(
                width: 1,
                height: 20,
                color: isDark ? AppColors.amoledBorder : AppColors.lightBorder,
                margin: const EdgeInsets.symmetric(horizontal: 2),
              ),

              // Pen Tools
              _buildToolButton(
                icon: Icons.edit_outlined,
                label: 'Ballpoint',
                isSelected: currentTool == PenType.ballpoint,
                isDark: isDark,
                onTap: () => inkingNotifier.setPenType(PenType.ballpoint),
              ),
              _buildToolButton(
                icon: Icons.brush_outlined,
                label: 'Calligraphy',
                isSelected: currentTool == PenType.calligraphy,
                isDark: isDark,
                onTap: () => inkingNotifier.setPenType(PenType.calligraphy),
              ),
              _buildToolButton(
                icon: Icons.highlight_outlined,
                label: 'Highlighter',
                isSelected: currentTool == PenType.highlighter,
                isDark: isDark,
                onTap: () => inkingNotifier.setPenType(PenType.highlighter),
              ),
              _buildToolButton(
                icon: Icons.create_outlined,
                label: 'Pencil',
                isSelected: currentTool == PenType.pencil,
                isDark: isDark,
                onTap: () => inkingNotifier.setPenType(PenType.pencil),
              ),
              _buildToolButton(
                icon: Icons.auto_fix_high_outlined,
                label: 'Eraser',
                isSelected: currentTool == PenType.eraser,
                isDark: isDark,
                onTap: () => inkingNotifier.setPenType(PenType.eraser),
              ),
              _buildToolButton(
                icon: Icons.gesture_outlined,
                label: 'Lasso',
                isSelected: currentTool == PenType.lasso,
                isDark: isDark,
                onTap: () => inkingNotifier.setPenType(PenType.lasso),
              ),

              Container(
                width: 1,
                height: 20,
                color: isDark ? AppColors.amoledBorder : AppColors.lightBorder,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),

              // Color Palette Selector
              ...AppColors.inkPalette.take(4).map((c) {
                final isSelected = inkingState.toolConfig.color == c;
                return GestureDetector(
                  onTap: () => inkingNotifier.setPenColor(c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.samsungOrange : (isDark ? Colors.white24 : Colors.black12),
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                  ),
                );
              }),

              Container(
                width: 1,
                height: 20,
                color: isDark ? AppColors.amoledBorder : AppColors.lightBorder,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),

              // Undo / Redo
              IconButton(
                icon: const Icon(Icons.undo, size: 18),
                tooltip: 'Undo',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                onPressed: docNotifier.canUndo ? () => docNotifier.undo() : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo, size: 18),
                tooltip: 'Redo',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                onPressed: docNotifier.canRedo ? () => docNotifier.redo() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.samsungOrange.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? AppColors.samsungOrange
                : (isDark ? AppColors.amoledTextPrimary : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}

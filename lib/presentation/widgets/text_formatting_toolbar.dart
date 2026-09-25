import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_themes.dart';
import '../controllers/document_controller.dart';
import '../controllers/inking_controller.dart';
import '../controllers/editor_formatting_bridge.dart';
import '../../core/diagnostics/performance_benchmark.dart';

/// Samsung Notes Style Floating Island Formatting Toolbar
/// Centered floating pill with active states, focus retention, and instant in-place formatting
class TextFormattingToolbar extends ConsumerWidget {
  final ScrollController? scrollController;

  const TextFormattingToolbar({
    super.key,
    this.scrollController,
  });

  void _scrollToTop(WidgetRef ref) {
    if (scrollController != null && scrollController!.hasClients) {
      scrollController!.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    final bridge = ref.read(editorFormattingBridgeProvider);
    bridge.bodyFocusNode?.requestFocus();
    bridge.bodyController?.selection = const TextSelection.collapsed(offset: 0);
  }

  void _scrollToBottom(WidgetRef ref) {
    if (scrollController != null && scrollController!.hasClients) {
      scrollController!.animateTo(
        scrollController!.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    final bridge = ref.read(editorFormattingBridgeProvider);
    final textLen = bridge.bodyController?.text.length ?? 0;
    bridge.bodyFocusNode?.requestFocus();
    bridge.bodyController?.selection = TextSelection.collapsed(offset: textLen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PerformanceBenchmarkService.measure('toolbar_build', () {
      final inkingState = ref.watch(inkingProvider);
      final inkingNotifier = ref.read(inkingProvider.notifier);
      final docNotifier = ref.read(documentProvider.notifier);
      final bridge = ref.watch(editorFormattingBridgeProvider);
      final activeTheme = ref.watch(appThemeProvider);

      return PerformanceProbeWidget(
        tag: 'toolbar',
        child: FocusScope(
          canRequestFocus: false, // Prevents toolbar from stealing focus from text field & keyboard
          child: Container(
        width: double.infinity,
        color: Colors.transparent,
        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10, top: 4),
        child: SafeArea(
          top: false,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: activeTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: activeTheme.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: activeTheme.isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Bold (B)
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: Icons.format_bold_rounded,
                      tooltip: 'Bold',
                      isSelected: bridge.isBold,
                      onTap: () => bridge.toggleBold(),
                    ),

                    // 2. Italic (I)
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: Icons.format_italic_rounded,
                      tooltip: 'Italic',
                      isSelected: bridge.isItalic,
                      onTap: () => bridge.toggleItalic(),
                    ),

                    // 3. Strikethrough (S)
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: Icons.strikethrough_s_rounded,
                      tooltip: 'Strikethrough',
                      isSelected: bridge.isStrike,
                      onTap: () => bridge.toggleStrike(),
                    ),

                    // Divider
                    Container(
                      width: 1.2,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: activeTheme.border,
                    ),

                    // 4. Bullet List (•)
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: Icons.format_list_bulleted_rounded,
                      tooltip: 'Bullet List',
                      isSelected: false,
                      onTap: () => bridge.toggleLinePrefix('- '),
                    ),

                    // 5. Interactive Checklist (☑)
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: Icons.checklist_rtl_rounded,
                      tooltip: 'Checklist',
                      isSelected: false,
                      onTap: () => bridge.toggleLinePrefix('[ ] '),
                    ),

                    // 6. Blockquote (”)
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: Icons.format_quote_rounded,
                      tooltip: 'Quote',
                      isSelected: false,
                      onTap: () => bridge.toggleLinePrefix('> '),
                    ),

                    // Divider
                    Container(
                      width: 1.2,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: activeTheme.border,
                    ),

                    // 7. Handwriting / Drawing Toggle
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: inkingState.isInkingMode ? Icons.edit_rounded : Icons.draw_outlined,
                      tooltip: inkingState.isInkingMode ? 'Switch to Typing' : 'Handwriting / Drawing',
                      isSelected: inkingState.isInkingMode,
                      activeColor: AppColors.primaryBlue,
                      onTap: () => inkingNotifier.toggleInkingMode(!inkingState.isInkingMode),
                    ),

                    // 8. Undo
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: Icons.undo_rounded,
                      tooltip: 'Undo',
                      isEnabled: docNotifier.canUndo,
                      onTap: docNotifier.canUndo ? () => docNotifier.undo() : () {},
                    ),

                    // Divider
                    Container(
                      width: 1.2,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: activeTheme.border,
                    ),

                    // 9. Go to Top
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: Icons.vertical_align_top_rounded,
                      tooltip: 'Go to Top',
                      isSelected: false,
                      onTap: () => _scrollToTop(ref),
                    ),

                    // 10. Go to Bottom
                    _buildIslandBtn(
                      context: context,
                      activeTheme: activeTheme,
                      icon: Icons.vertical_align_bottom_rounded,
                      tooltip: 'Go to Bottom',
                      isSelected: false,
                      onTap: () => _scrollToBottom(ref),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
    });
  }

  Widget _buildIslandBtn({
    required BuildContext context,
    required AppThemePalette activeTheme,
    required IconData icon,
    required String tooltip,
    bool isSelected = false,
    bool isEnabled = true,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final effectiveActive = activeColor ?? Theme.of(context).colorScheme.primary;
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
              color: isSelected ? effectiveActive : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: isSelected
                  ? (ThemeData.estimateBrightnessForColor(effectiveActive) == Brightness.dark ? Colors.white : Colors.black)
                  : (isEnabled ? activeTheme.textPrimary : activeTheme.textSecondary.withValues(alpha: 0.35)),
            ),
          ),
        ),
      ),
    );
  }
}

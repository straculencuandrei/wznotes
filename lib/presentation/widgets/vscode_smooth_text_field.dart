import 'package:flutter/material.dart';

/// VSCode Smooth Caret Animation TextField
/// Uses TweenAnimationBuilder for silky smooth cursor gliding with zero framework assertion issues
class VSCodeSmoothTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String hintText;
  final TextStyle hintStyle;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const VSCodeSmoothTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.hintText,
    required this.hintStyle,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
  });

  @override
  State<VSCodeSmoothTextField> createState() => _VSCodeSmoothTextFieldState();
}

class _VSCodeSmoothTextFieldState extends State<VSCodeSmoothTextField> with SingleTickerProviderStateMixin {
  Offset _currentCaretOffset = Offset.zero;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _hasCalculated = false;

  @override
  void initState() {
    super.initState();

    // Soft breathing blink when idle
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    widget.controller.addListener(_onTextOrSelectionChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextOrSelectionChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _blinkController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onTextOrSelectionChanged() {
    if (!mounted) return;
    _blinkController.value = 1.0; // Keep cursor fully visible during typing
    setState(() {});
  }

  Offset _calculateCaretOffset(double maxWidth) {
    if (maxWidth <= 0) return Offset.zero;

    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final int cursorIndex = selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    // Use zero-width space '\u200B' when text is empty so TextPainter always has full font ascent on line 1!
    final textPainter = TextPainter(
      text: TextSpan(text: text.isEmpty ? '\u200B' : text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    textPainter.layout(maxWidth: maxWidth);

    final TextPosition textPosition = TextPosition(offset: text.isEmpty ? 0 : cursorIndex);
    final Offset pos = textPainter.getOffsetForCaret(
      textPosition,
      Rect.fromLTWH(0, 0, 2.4, widget.style.fontSize ?? 17.0),
    );

    return pos;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.style.fontSize ?? 17.0;
    final fontHeight = widget.style.height ?? 1.6;
    final caretHeight = fontSize * 1.16;
    final verticalOffset = (fontSize * fontHeight - caretHeight) / 2.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetOffset = _calculateCaretOffset(constraints.maxWidth);

        if (!_hasCalculated && constraints.maxWidth > 0) {
          _currentCaretOffset = targetOffset;
          _hasCalculated = true;
        }

        final isCollapsed = widget.controller.selection.isCollapsed || widget.controller.selection.baseOffset < 0;
        final showSmoothCaret = widget.focusNode.hasFocus && isCollapsed && _hasCalculated;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Native TextField (Native cursor hidden so smooth gliding caret displays)
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: widget.textCapitalization,
              showCursor: false, // Hides rigid default jump cursor
              style: widget.style,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: widget.hintStyle,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                widget.onChanged?.call(val);
              },
            ),

            // 2. VSCode Smooth Gliding Animated Caret
            if (showSmoothCaret)
              TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(begin: _currentCaretOffset, end: targetOffset),
                duration: const Duration(milliseconds: 95),
                curve: Curves.easeOutCubic,
                onEnd: () {
                  _currentCaretOffset = targetOffset;
                },
                builder: (context, animatedOffset, _) {
                  return Positioned(
                    left: animatedOffset.dx,
                    top: animatedOffset.dy + verticalOffset,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _blinkAnimation,
                        builder: (context, _) {
                          return Opacity(
                            opacity: _blinkAnimation.value,
                            child: Container(
                              width: 2.4,
                              height: caretHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9100), // Clean Warm Amber
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

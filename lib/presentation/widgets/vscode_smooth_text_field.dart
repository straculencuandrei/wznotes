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
  Offset? _currentCaretOffset;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  int _lastTextLength = 0;

  @override
  void initState() {
    super.initState();
    _lastTextLength = widget.controller.text.length;

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

  Offset _calculateCaretOffset(BuildContext context, double maxWidth) {
    if (maxWidth <= 0) return Offset.zero;

    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final int cursorIndex = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    final fontSize = widget.style.fontSize ?? 17.0;

    final TextSpan span = text.isEmpty
        ? TextSpan(text: 'A', style: widget.style)
        : widget.controller.buildTextSpan(
            context: context,
            style: widget.style,
            withComposing: false,
          );

    final textPainter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    textPainter.layout(maxWidth: maxWidth);

    final TextPosition textPosition = TextPosition(offset: text.isEmpty ? 0 : cursorIndex.clamp(0, text.length));
    final Offset pos = textPainter.getOffsetForCaret(
      textPosition,
      Rect.fromLTWH(0, 0, 2.4, fontSize),
    );

    return pos;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.style.fontSize ?? 17.0;
    final caretHeight = fontSize * 1.12;

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetOffset = _calculateCaretOffset(context, constraints.maxWidth);
        final currentTextLen = widget.controller.text.length;
        final int lengthDiff = (currentTextLen - _lastTextLength).abs();
        _lastTextLength = currentTextLen;

        // If large jump / paste occurred (>3 chars or >80px jump), snap immediately without floating animation
        if (_currentCaretOffset == null || lengthDiff > 3 || (_currentCaretOffset! - targetOffset).distance > 80) {
          _currentCaretOffset = targetOffset;
        }

        final isCollapsed = widget.controller.selection.isCollapsed || widget.controller.selection.baseOffset < 0;
        final showSmoothCaret = widget.focusNode.hasFocus && isCollapsed;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Native TextField with isDense: true to guarantee zero hidden padding
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: widget.textCapitalization,
              showCursor: false, // Hides rigid default jump cursor
              style: widget.style,
              decoration: InputDecoration(
                isDense: true, // Eliminates hidden InputDecorator vertical padding
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: widget.hintStyle,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                widget.onChanged?.call(val);
              },
            ),

            // 2. VSCode Smooth Gliding Animated Caret (Exact Native Alignment on Line 1 & all lines)
            if (showSmoothCaret)
              TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(begin: _currentCaretOffset ?? targetOffset, end: targetOffset),
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOutCubic,
                onEnd: () {
                  _currentCaretOffset = targetOffset;
                },
                builder: (context, animatedOffset, _) {
                  return Positioned(
                    left: animatedOffset.dx,
                    top: animatedOffset.dy,
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

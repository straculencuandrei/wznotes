import 'package:flutter/material.dart';

/// VSCode Ultra-Smooth Gliding Caret Animation TextField for Android
/// Provides silky smooth interpolation between cursor positions with a subtle trailing fade
class SmoothCaretField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String hintText;
  final TextStyle hintStyle;
  final ValueChanged<String>? onChanged;

  const SmoothCaretField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.hintText,
    required this.hintStyle,
    this.onChanged,
  });

  @override
  State<SmoothCaretField> createState() => _SmoothCaretFieldState();
}

class _SmoothCaretFieldState extends State<SmoothCaretField> with TickerProviderStateMixin {
  late AnimationController _moveController;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  Offset _oldCaretOffset = Offset.zero;
  Offset _targetCaretOffset = Offset.zero;
  double _caretHeight = 18.0;
  double _verticalAdjustment = 6.0;
  bool _hasInitialPosition = false;
  double _currentWidth = 350.0;

  @override
  void initState() {
    super.initState();

    // 1. Silky Smooth Gliding Controller (125ms ease-out quart for ultra-fluid motion)
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 125),
    );

    // 2. Soft Breathing Blink (idle state)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.05, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOutSine),
    );

    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _moveController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
    if (widget.focusNode.hasFocus) {
      _computeCaret(_currentWidth);
    }
  }

  void _onTextChanged() {
    if (!mounted) return;
    _blinkController.value = 1.0;
    _computeCaret(_currentWidth);
  }

  void _computeCaret(double width) {
    if (width <= 0) return;
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final int cursorIndex = selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    textPainter.layout(maxWidth: width);

    final fontSize = widget.style.fontSize ?? 17.0;
    final fontHeight = widget.style.height ?? 1.6;

    final TextPosition textPosition = TextPosition(offset: cursorIndex);
    final Offset caretPos = textPainter.getOffsetForCaret(
      textPosition,
      Rect.fromLTWH(0, 0, 2.0, fontSize),
    );

    // Exact height matching glyph cap-height (same height as text)
    _caretHeight = fontSize * 1.08;
    // Lowered offset so it aligns with glyph baseline and text center
    _verticalAdjustment = (fontSize * (fontHeight - 1.0) / 2.0) + (fontSize * 0.28);

    if (!_hasInitialPosition) {
      _oldCaretOffset = caretPos;
      _targetCaretOffset = caretPos;
      _hasInitialPosition = true;
    } else if (_targetCaretOffset != caretPos) {
      _oldCaretOffset = _targetCaretOffset;
      _targetCaretOffset = caretPos;
      _moveController.forward(from: 0.0);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_currentWidth != constraints.maxWidth) {
          _currentWidth = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _computeCaret(_currentWidth);
          });
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Core Native Editable TextField
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              showCursor: false, // Hides rigid default cursor
              style: widget.style,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: widget.hintStyle,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                widget.onChanged?.call(val);
                _computeCaret(_currentWidth);
              },
            ),

            // 2. VSCode Ultra-Smooth Gliding Caret with Trailing Fade
            if (widget.focusNode.hasFocus && _hasInitialPosition)
              AnimatedBuilder(
                animation: Listenable.merge([_moveController, _blinkAnimation]),
                builder: (context, _) {
                  // Silky smooth quartic glide
                  final double t = CurvedAnimation(
                    parent: _moveController,
                    curve: Curves.easeOutQuart,
                  ).value;

                  final double currentX = _oldCaretOffset.dx + (_targetCaretOffset.dx - _oldCaretOffset.dx) * t;
                  final double currentY = _oldCaretOffset.dy + (_targetCaretOffset.dy - _oldCaretOffset.dy) * t;
                  final double opacity = _moveController.isAnimating ? 1.0 : _blinkAnimation.value;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Trailing soft motion blur fade during fast typing
                      if (_moveController.isAnimating)
                        Positioned(
                          left: _oldCaretOffset.dx + (_targetCaretOffset.dx - _oldCaretOffset.dx) * (t * 0.7),
                          top: currentY + _verticalAdjustment,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: (1.0 - t).clamp(0.0, 0.4),
                              child: Container(
                                width: 2.2,
                                height: _caretHeight,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9100),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Main Smooth Caret
                      Positioned(
                        left: currentX,
                        top: currentY + _verticalAdjustment,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: Container(
                              width: 2.2,
                              height: _caretHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9100), // Clean Warm Amber
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

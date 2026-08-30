import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// VSCode Smooth Caret Animation TextField
/// Glides smoothly from character to character on keystrokes and pulses softly when idle
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
  double _caretHeight = 24.0;
  bool _hasCalculated = false;

  @override
  void initState() {
    super.initState();

    // 1. Smooth Position Interpolation Controller (80ms snappy cubic glide)
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );

    // 2. Soft Breathing Blink Controller (when idle)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    widget.controller.addListener(_updateCaretPosition);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateCaretPosition);
    widget.focusNode.removeListener(_onFocusChanged);
    _moveController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
    if (widget.focusNode.hasFocus) {
      _updateCaretPosition();
    }
  }

  void _updateCaretPosition() {
    if (!mounted) return;

    // Reset blink on typing
    _blinkController.value = 1.0;

    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final int cursorIndex = selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    // Calculate exact caret position using TextPainter
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final double maxWidth = renderBox?.size.width ?? 350.0;
    textPainter.layout(maxWidth: maxWidth > 0 ? maxWidth : 350.0);

    final TextPosition textPosition = TextPosition(offset: cursorIndex);
    final Offset caretPos = textPainter.getOffsetForCaret(
      textPosition,
      Rect.fromLTWH(0, 0, 2.5, widget.style.fontSize ?? 17.0),
    );

    _caretHeight = widget.style.fontSize != null ? widget.style.fontSize! * (widget.style.height ?? 1.5) : 24.0;

    if (!_hasCalculated) {
      _oldCaretOffset = caretPos;
      _targetCaretOffset = caretPos;
      _hasCalculated = true;
    } else {
      _oldCaretOffset = _targetCaretOffset;
      _targetCaretOffset = caretPos;
      _moveController.forward(from: 0.0);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Real TextField with transparent native cursor (so our smooth caret renders)
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
            _updateCaretPosition();
          },
        ),

        // 2. VSCode Smooth Sliding Caret Overlay
        if (widget.focusNode.hasFocus && _hasCalculated)
          AnimatedBuilder(
            animation: Listenable.merge([_moveController, _blinkAnimation]),
            builder: (context, _) {
              // Interpolate smoothly between old and target position
              final double t = CurvedAnimation(
                parent: _moveController,
                curve: Curves.easeOutCubic,
              ).value;

              final double currentX = _oldCaretOffset.dx + (_targetCaretOffset.dx - _oldCaretOffset.dx) * t;
              final double currentY = _oldCaretOffset.dy + (_targetCaretOffset.dy - _oldCaretOffset.dy) * t;

              // Don't blink while moving
              final double opacity = _moveController.isAnimating ? 1.0 : _blinkAnimation.value;

              return Positioned(
                left: currentX,
                top: currentY + 2.0,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 2.6,
                    height: _caretHeight * 0.85,
                    decoration: BoxDecoration(
                      color: AppColors.samsungOrange,
                      borderRadius: BorderRadius.circular(2.0),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.samsungOrange.withValues(alpha: 0.6),
                          blurRadius: 3.5,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

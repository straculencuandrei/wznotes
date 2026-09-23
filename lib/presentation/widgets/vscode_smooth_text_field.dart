import 'package:flutter/material.dart';

/// VSCode Smooth Caret Animation TextField
/// Silky-smooth gliding horizontal caret with exact font metrics and vertical centering.
/// Y position is strictly locked to prevent any downward drift or distortion.
class VSCodeSmoothTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String hintText;
  final TextStyle hintStyle;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const VSCodeSmoothTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.hintText,
    required this.hintStyle,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
  });

  @override
  State<VSCodeSmoothTextField> createState() => _VSCodeSmoothTextFieldState();
}

class _VSCodeSmoothTextFieldState extends State<VSCodeSmoothTextField> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  late AnimationController _glideController;
  late Tween<double> _xTween;
  late Animation<double> _xAnimation;

  double _currentX = 0.0;
  double _currentY = 0.0;
  int _lastTextLength = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _lastTextLength = widget.controller.text.length;

    // Breathing blink animation when idle
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // VSCode smooth horizontal glide animation (80ms easeOutCubic)
    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );

    _xTween = Tween<double>(begin: 0.0, end: 0.0);
    _xAnimation = _xTween.animate(
      CurvedAnimation(parent: _glideController, curve: Curves.easeOutCubic),
    );

    widget.controller.addListener(_onTextOrSelectionChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextOrSelectionChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _blinkController.dispose();
    _glideController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onTextOrSelectionChanged() {
    if (!mounted) return;
    _blinkController.value = 1.0; // Keep cursor visible during typing
    setState(() {});
  }

  Offset _calculateCaretOffset(BuildContext context, double maxWidth) {
    if (maxWidth <= 0) return Offset.zero;

    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final int cursorIndex = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    final fontSize = widget.style.fontSize ?? 17.0;
    final heightMultiplier = widget.style.height ?? 1.5;
    final caretHeight = fontSize * 1.15;
    final lineHeight = fontSize * heightMultiplier;
    // Perfectly centers the bar vertically within the line ("not upper, not downer")
    final verticalOffset = (lineHeight - caretHeight) / 2;

    final strut = StrutStyle.fromTextStyle(widget.style, forceStrutHeight: true);

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
      maxLines: widget.maxLines,
      strutStyle: strut,
      textScaler: MediaQuery.textScalerOf(context),
    );

    textPainter.layout(maxWidth: maxWidth);

    // upstream affinity prevents wrapping down to the next line at the end of a line
    final TextPosition textPosition = TextPosition(
      offset: text.isEmpty ? 0 : cursorIndex.clamp(0, text.length),
      affinity: TextAffinity.upstream,
    );

    final Offset pos = textPainter.getOffsetForCaret(
      textPosition,
      Rect.fromLTWH(0, 0, 2.4, caretHeight),
    );

    return Offset(pos.dx, pos.dy + verticalOffset);
  }

  void _updateCaret(Offset targetOffset) {
    final currentTextLen = widget.controller.text.length;
    final int lengthDiff = (currentTextLen - _lastTextLength).abs();
    _lastTextLength = currentTextLen;

    final bool isLineChange = (_currentY - targetOffset.dy).abs() > 4.0;
    final double xDiff = (_currentX - targetOffset.dx).abs();
    final bool isLargeJump = !_initialized || isLineChange || lengthDiff > 3 || xDiff > 60.0;

    // CRITICAL: Y ALWAYS snaps immediately — never animates vertically.
    // This eliminates any possibility of downward drifting, dipping, or glitching.
    _currentY = targetOffset.dy;

    if (isLargeJump) {
      _currentX = targetOffset.dx;
      _xTween.begin = targetOffset.dx;
      _xTween.end = targetOffset.dx;
      _glideController.value = 1.0;
      _initialized = true;
    } else {
      // Smooth horizontal glide from current interpolated position to target X
      final startX = _glideController.isAnimating ? _xAnimation.value : _currentX;
      _currentX = targetOffset.dx;
      _xTween.begin = startX;
      _xTween.end = targetOffset.dx;
      _glideController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.style.fontSize ?? 17.0;
    final caretHeight = fontSize * 1.15;
    final strut = StrutStyle.fromTextStyle(widget.style, forceStrutHeight: true);

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetOffset = _calculateCaretOffset(context, constraints.maxWidth);
        _updateCaret(targetOffset);

        final isCollapsed = widget.controller.selection.isCollapsed || widget.controller.selection.baseOffset < 0;
        final showSmoothCaret = widget.focusNode.hasFocus && isCollapsed;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Native TextField with IDENTICAL strutStyle to guarantee 1:1 font metric match
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
              showCursor: false, // Smooth gliding custom caret replaces default jump cursor
              style: widget.style,
              strutStyle: strut,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: widget.hintStyle,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onChanged,
            ),

            // 2. VSCode Smooth Gliding Animated Caret
            if (showSmoothCaret)
              AnimatedBuilder(
                animation: Listenable.merge([_xAnimation, _blinkAnimation]),
                builder: (context, _) {
                  return Positioned(
                    left: _xAnimation.value,
                    top: _currentY, // Solid, vertically centered, locked to Android bulb
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _blinkAnimation.value,
                        child: Container(
                          width: 2.4,
                          height: caretHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9100), // Clean Warm Amber / Samsung Orange
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
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

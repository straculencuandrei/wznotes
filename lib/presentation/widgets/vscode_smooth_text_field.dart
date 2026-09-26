import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/diagnostics/performance_benchmark.dart';

/// Selection controls that suppress only the collapsed Android insertion teardrop bulb,
/// while fully preserving range selection handles and the Copy/Paste/Cut action toolbar.
class SmoothCaretSelectionControls extends MaterialTextSelectionControls {
  @override
  Size getHandleSize(double textLineHeight) {
    return Size.zero;
  }

  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textHeight, [VoidCallback? onTap]) {
    if (type == TextSelectionHandleType.collapsed) {
      // Suppresses the floating detached bulb on Android while keeping selection range handles intact
      return const SizedBox.shrink();
    }
    return super.buildHandle(context, type, textHeight, onTap);
  }
}

RenderEditable? _findRenderEditable(RenderObject? root) {
  if (root == null) return null;
  if (root is RenderEditable) return root;
  RenderEditable? found;
  root.visitChildren((child) {
    if (found != null) return;
    found = _findRenderEditable(child);
  });
  return found;
}

/// VSCode Smooth Caret Animation TextField
/// Silky-smooth horizontal gliding caret with exact font metrics.
/// Y position strictly snaps to prevent any diagonal lag or distortion across line wraps.
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
  final Color? caretColor;

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
    this.caretColor,
  });

  @override
  State<VSCodeSmoothTextField> createState() => _VSCodeSmoothTextFieldState();
}

class _VSCodeSmoothTextFieldState extends State<VSCodeSmoothTextField> with TickerProviderStateMixin {
  final SmoothCaretSelectionControls _selectionControls = SmoothCaretSelectionControls();
  final GlobalKey _textFieldKey = GlobalKey();

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  late AnimationController _glideController;
  late Tween<double> _xTween;
  late Animation<double> _xAnimation;

  final ValueNotifier<double> _caretYNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _caretHeightNotifier = ValueNotifier<double>(24.0);

  double _currentX = 0.0;
  double _currentY = 0.0;
  int _lastTextLength = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _lastTextLength = widget.controller.text.length;

    // Breathing blink animation when idle (only runs when focused)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _blinkAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // VSCode smooth horizontal glide animation (50ms easeOutCubic)
    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );

    _xTween = Tween<double>(begin: 0.0, end: 0.0);
    _xAnimation = _xTween.animate(
      CurvedAnimation(parent: _glideController, curve: Curves.easeOutCubic),
    );

    _glideController.addListener(() {
      PerformanceBenchmarkService.instance.recordProbe('caret_glide_tick', 1.0);
    });
    _blinkController.addListener(() {
      PerformanceBenchmarkService.instance.recordProbe('caret_blink_tick', 1.0);
    });

    widget.controller.addListener(_onTextOrSelectionChanged);
    widget.focusNode.addListener(_onFocusChanged);

    // Initial position sync once rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncCaretFromEngine();
    });
  }

  Timer? _idleBlinkPauseTimer;

  void _resetBlinkState() {
    _idleBlinkPauseTimer?.cancel();
    if (!widget.focusNode.hasFocus) {
      _blinkController.stop();
      return;
    }
    // Solid visible caret while actively interacting
    _blinkController.value = 1.0;
    // Resume gentle breathing blink after 600ms of pause, then stop after 5s AFK to save battery
    _idleBlinkPauseTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && widget.focusNode.hasFocus) {
        _blinkController.repeat(reverse: true);
        _idleBlinkPauseTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            _blinkController.stop();
            _blinkController.value = 1.0; // Rest in solid visible state
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _idleBlinkPauseTimer?.cancel();
    widget.controller.removeListener(_onTextOrSelectionChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _blinkController.dispose();
    _glideController.dispose();
    _caretYNotifier.dispose();
    _caretHeightNotifier.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    _resetBlinkState();
    if (widget.focusNode.hasFocus) {
      PerformanceBenchmarkService.instance.onFocusAcquired('VSCodeSmoothTextField');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncCaretFromEngine();
      });
    } else {
      PerformanceBenchmarkService.instance.onFocusLost();
    }
  }

  RenderEditable? _cachedRenderEditable;

  Offset? _getRenderEditableCaretOffset([double? defaultHeight]) {
    final swTotal = Stopwatch()..start();
    try {
      final RenderBox? rootBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
      if (rootBox == null || !rootBox.hasSize) return null;

      if (_cachedRenderEditable == null || !_cachedRenderEditable!.attached) {
        final swFind = Stopwatch()..start();
        _cachedRenderEditable = _findRenderEditable(rootBox);
        swFind.stop();
        PerformanceBenchmarkService.instance.recordProbe('caret_find_render_editable', swFind.elapsedMicroseconds.toDouble());
      }
      final renderEditable = _cachedRenderEditable;
      if (renderEditable == null || !renderEditable.hasSize) return null;

      final text = widget.controller.text;
      final selection = widget.controller.selection;
      final int cursorIndex = (selection.isValid && selection.baseOffset >= 0)
          ? selection.baseOffset
          : text.length;

      // Follow the text engine's selection affinity (downstream) so that when a word
      // soft-wraps to a new row, the caret reliably moves to the new row with the word.
      final swRect = Stopwatch()..start();
      final caretRect = renderEditable.getLocalRectForCaret(
        TextPosition(
          offset: cursorIndex.clamp(0, text.length),
          affinity: selection.affinity,
        ),
      );
      swRect.stop();
      PerformanceBenchmarkService.instance.recordProbe('caret_get_local_rect', swRect.elapsedMicroseconds.toDouble());

      // Fast O(1) ancestor conversion: stops immediately at rootBox instead of traversing to screen root
      final swTrans = Stopwatch()..start();
      final localOffset = renderEditable.localToGlobal(caretRect.topLeft, ancestor: rootBox);
      swTrans.stop();
      PerformanceBenchmarkService.instance.recordProbe('caret_local_to_global', swTrans.elapsedMicroseconds.toDouble());

      final h = caretRect.height > 0 ? caretRect.height : (defaultHeight ?? 24.0);
      _caretHeightNotifier.value = h;

      return localOffset;
    } finally {
      swTotal.stop();
      PerformanceBenchmarkService.instance.recordProbe('caret_sync_engine', swTotal.elapsedMicroseconds.toDouble());
    }
  }

  void _syncCaretFromEngine() {
    final fontSize = widget.style.fontSize ?? 17.0;
    final heightMultiplier = widget.style.height ?? 1.6;
    final defaultHeight = fontSize * heightMultiplier;

    final offset = _getRenderEditableCaretOffset(defaultHeight);
    if (offset != null) {
      _updateCaret(offset);
    }
  }

  void _updateCaret(Offset targetOffset) {
    PerformanceBenchmarkService.measure('caret_update', () {
      final currentTextLen = widget.controller.text.length;
      final int lengthDiff = (currentTextLen - _lastTextLength).abs();
      _lastTextLength = currentTextLen;

      final bool isLineChange = (_currentY - targetOffset.dy).abs() >= 2.0;
      final double xDiff = (_currentX - targetOffset.dx).abs();
      final bool isLargeJump = !_initialized || isLineChange || lengthDiff > 3 || xDiff > 120.0;

      // Y position always snaps immediately — never animates vertically
      _currentY = targetOffset.dy;
      _caretYNotifier.value = targetOffset.dy;

      if (isLargeJump) {
        _currentX = targetOffset.dx;
        _xTween.begin = targetOffset.dx;
        _xTween.end = targetOffset.dx;
        _glideController.value = 1.0;
        _initialized = true;
      } else if (xDiff > 0.5) {
        // Smooth horizontal glide from previous target X to new target X
        final startX = _currentX;
        _currentX = targetOffset.dx;
        _xTween.begin = startX;
        _xTween.end = targetOffset.dx;
        _glideController.forward(from: 0.0);
      }
    });
  }

  void _onTextOrSelectionChanged() {
    if (!mounted) return;
    _resetBlinkState();

    // Settle with post frame callback once layout completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncCaretFromEngine();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkService.measure('vscode_textfield_build', () {
      final fontSize = widget.style.fontSize ?? 17.0;
      final heightMultiplier = widget.style.height ?? 1.6;
      final defaultCaretHeight = fontSize * heightMultiplier;
      final strut = StrutStyle.fromTextStyle(widget.style, forceStrutHeight: true);

      final effectiveCaretColor = widget.caretColor ?? Theme.of(context).colorScheme.primary;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Native TextField with exact font metrics and suppressed collapsed handle
          PerformanceProbeWidget(
            tag: 'vscode_textfield',
            child: TextField(
              key: _textFieldKey,
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
              showCursor: false, // Smooth gliding custom caret replaces default jump cursor
              selectionControls: _selectionControls, // Suppresses only the collapsed teardrop bulb!
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
          ),

          // 2. VSCode Smooth Gliding Animated Caret (Hardware translated with zero layout thrashing)
          Positioned(
            top: 0,
            left: 0,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _xAnimation,
                  _blinkAnimation,
                  _caretYNotifier,
                  _caretHeightNotifier,
                  widget.focusNode,
                  widget.controller,
                ]),
                builder: (context, _) {
                  final isCollapsed = widget.controller.selection.isCollapsed || widget.controller.selection.baseOffset < 0;
                  final showSmoothCaret = widget.focusNode.hasFocus && isCollapsed;
                  if (!showSmoothCaret) return const SizedBox.shrink();
                  return Transform.translate(
                    offset: Offset(_xAnimation.value, _caretYNotifier.value),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _blinkAnimation.value,
                        child: Container(
                          width: 2.4,
                          height: _caretHeightNotifier.value > 0 ? _caretHeightNotifier.value : defaultCaretHeight,
                          decoration: BoxDecoration(
                            color: effectiveCaretColor,
                            borderRadius: BorderRadius.circular(1.2),
                            boxShadow: [
                              BoxShadow(
                                color: effectiveCaretColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }
}

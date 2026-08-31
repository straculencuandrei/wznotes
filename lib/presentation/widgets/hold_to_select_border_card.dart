import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// A card wrapper that renders an animated glowing border circling clockwise
/// from top-center when held down, activating selection or actions upon 360° completion.
class HoldToSelectBorderCard extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onHoldCompleted;
  final double borderRadius;
  final Color glowColor;
  final Duration holdDuration;

  const HoldToSelectBorderCard({
    super.key,
    required this.child,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onHoldCompleted,
    this.borderRadius = 20.0,
    this.glowColor = AppColors.samsungOrange,
    this.holdDuration = const Duration(milliseconds: 420),
  });

  @override
  State<HoldToSelectBorderCard> createState() => _HoldToSelectBorderCardState();
}

class _HoldToSelectBorderCardState extends State<HoldToSelectBorderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHolding = false;
  DateTime? _lastHoldCompletedTime;
  Timer? _holdStartTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _triggerComplete();
        }
      });
  }

  @override
  void dispose() {
    _holdStartTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _triggerComplete() {
    _lastHoldCompletedTime = DateTime.now();
    HapticFeedback.heavyImpact();
    widget.onHoldCompleted();
    _controller.reset();
    if (mounted) {
      setState(() {
        _isHolding = false;
      });
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.isSelectionMode) return;
    _holdStartTimer?.cancel();
    // 140ms grace period so quick taps to open a note never flicker or trigger hold state
    _holdStartTimer = Timer(const Duration(milliseconds: 140), () {
      if (mounted && !widget.isSelectionMode) {
        setState(() {
          _isHolding = true;
        });
        _controller.forward(from: 0.0);
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _holdStartTimer?.cancel();
    if (!_isHolding) return;
    if (mounted) {
      setState(() {
        _isHolding = false;
      });
    }
    if (_controller.isAnimating && _controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _holdStartTimer?.cancel();
    if (!_isHolding) return;
    if (mounted) {
      setState(() {
        _isHolding = false;
      });
    }
    _controller.reverse();
  }

  void _handleTap() {
    // Prevent accidental unhold/deselection when releasing finger after hold completes
    if (_lastHoldCompletedTime != null) {
      final elapsed = DateTime.now().difference(_lastHoldCompletedTime!).inMilliseconds;
      if (elapsed < 450) {
        return;
      }
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;

            return Stack(
              children: [
                // Base Card Content
                AnimatedScale(
                  scale: _isHolding ? 0.975 : (widget.isSelected ? 0.98 : 1.0),
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      border: widget.isSelected
                          ? Border.all(color: widget.glowColor, width: 2.0)
                          : null,
                    ),
                    child: widget.child,
                  ),
                ),

                // Animated Perimeter Trace Painter (Active while holding)
                if (progress > 0.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _HoldProgressBorderPainter(
                          progress: progress,
                          radius: widget.borderRadius,
                          color: widget.glowColor,
                        ),
                      ),
                    ),
                  ),

                // Selected Checkmark Badge (Top Right with smooth pop-in animation)
                Positioned(
                  top: 10,
                  right: 10,
                  child: IgnorePointer(
                    child: AnimatedScale(
                      scale: widget.isSelectionMode ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: widget.isSelectionMode ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isSelected ? widget.glowColor : const Color(0x80000000),
                            border: Border.all(
                              color: widget.isSelected ? Colors.transparent : Colors.white60,
                              width: 1.8,
                            ),
                            boxShadow: widget.isSelected
                                ? [
                                    BoxShadow(
                                      color: widget.glowColor.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: widget.isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.black, size: 18)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter that draws a path starting from top-center and tracing clockwise
/// along the rounded rectangle perimeter proportional to `progress` (0.0 to 1.0).
class _HoldProgressBorderPainter extends CustomPainter {
  final double progress;
  final double radius;
  final Color color;

  _HoldProgressBorderPainter({
    required this.progress,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final double w = size.width;
    final double h = size.height;
    final double r = radius.clamp(0.0, [w / 2, h / 2].reduce((a, b) => a < b ? a : b));

    // Construct path starting precisely at top-center (w / 2, 0) and moving clockwise
    final path = Path();
    path.moveTo(w / 2, 0);

    // Top-right horizontal line
    path.lineTo(w - r, 0);
    // Top-right corner arc
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    // Right vertical line
    path.lineTo(w, h - r);
    // Bottom-right corner arc
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));
    // Bottom horizontal line
    path.lineTo(r, h);
    // Bottom-left corner arc
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
    // Left vertical line
    path.lineTo(0, r);
    // Top-left corner arc
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    // Top-left to center closing segment
    path.lineTo(w / 2, 0);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final totalLength = metric.length;
    final extractLength = totalLength * progress.clamp(0.0, 1.0);
    final extractPath = metric.extractPath(0.0, extractLength);

    // Outer Glow / Bloom
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(extractPath, glowPaint);

    // Sharp Core Stroke
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(extractPath, corePaint);

    // Glowing Lead Head Dot
    if (progress > 0.02 && progress < 0.99) {
      final tangent = metric.getTangentForOffset(extractLength);
      if (tangent != null) {
        final dotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, 3.5, dotPaint);

        final dotGlow = Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawCircle(tangent.position, 5.0, dotGlow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HoldProgressBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color;
  }
}

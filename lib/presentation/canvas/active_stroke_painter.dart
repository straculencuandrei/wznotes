import 'package:flutter/material.dart';
import '../../core/math/bezier_spline.dart';
import '../../domain/models/stroke_point.dart';
import '../../domain/models/pen_tool.dart';

/// Ultra low-latency painter for the transient active stroke in progress
class ActiveStrokePainter extends CustomPainter {
  final List<StrokePoint> points;
  final PenToolConfig toolConfig;

  const ActiveStrokePainter({
    required this.points,
    required this.toolConfig,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = toolConfig.color.withOpacity(toolConfig.opacity)
      ..blendMode = toolConfig.blendMode
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length == 1) {
      canvas.drawCircle(
        points.first.toOffset(),
        toolConfig.baseWidth / 2.0,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    if (toolConfig.type == PenType.highlighter) {
      final segments = BezierSplineCalculator.fitSpline(points, toolConfig.baseWidth, pressureExponent: 0.2);
      final ribbon = BezierSplineCalculator.buildRibbonPath(segments, samplesPerSegment: 4);
      canvas.drawPath(ribbon, paint..style = PaintingStyle.fill);
    } else {
      final segments = BezierSplineCalculator.fitSpline(points, toolConfig.baseWidth);
      for (final seg in segments) {
        final path = Path()
          ..moveTo(seg.p0.dx, seg.p0.dy)
          ..cubicTo(seg.c1.dx, seg.c1.dy, seg.c2.dx, seg.c2.dy, seg.p1.dx, seg.p1.dy);
        paint.strokeWidth = (seg.startWidth + seg.endWidth) / 2.0;
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    return true; // Active stroke repaints on every stylus touch event
  }
}

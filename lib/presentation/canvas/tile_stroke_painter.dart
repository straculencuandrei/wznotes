import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/math/bezier_spline.dart';
import '../../domain/models/vector_stroke.dart';
import '../../domain/models/pen_tool.dart';

/// High-performance CustomPainter for committed vector strokes within a spatial tile
class TileStrokePainter extends CustomPainter {
  final List<VectorStroke> strokes;
  final int currentAudioTimecodeMs; // -1 if no audio playback active

  const TileStrokePainter({
    required this.strokes,
    this.currentAudioTimecodeMs = -1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      // Audio-to-Ink Playback Highlighting / Ghosting
      double effectiveOpacity = stroke.opacity;
      if (currentAudioTimecodeMs >= 0 && stroke.audioTimecodeMs >= 0) {
        if (stroke.audioTimecodeMs > currentAudioTimecodeMs) {
          effectiveOpacity *= 0.25; // Future strokes dimmed
        }
      }

      final paint = Paint()
        ..color = stroke.color.withOpacity(effectiveOpacity)
        ..blendMode = stroke.blendMode
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      _renderStroke(canvas, stroke, paint);
    }
  }

  void _renderStroke(Canvas canvas, VectorStroke stroke, Paint paint) {
    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      canvas.drawCircle(
        p.toOffset(),
        stroke.baseWidth / 2.0,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    switch (stroke.toolType) {
      case PenType.highlighter:
        // Highlighter: Wide flat rectangular ribbon with multiply blend mode
        final segments = BezierSplineCalculator.fitSpline(
          stroke.points,
          stroke.baseWidth,
          pressureExponent: 0.2, // flat width
        );
        final Path ribbon = BezierSplineCalculator.buildRibbonPath(segments, samplesPerSegment: 6);
        final fillPaint = Paint()
          ..color = stroke.color.withOpacity(stroke.opacity)
          ..blendMode = BlendMode.multiply
          ..style = PaintingStyle.fill;
        canvas.drawPath(ribbon, fillPaint);
        break;

      case PenType.calligraphy:
        // Calligraphy: Angle-dependent chisel blade
        const double angle = 0.785398; // 45 degrees
        final bladeVec = Offset(cos(angle), sin(angle)) * (stroke.baseWidth / 2.0);

        for (int i = 0; i < stroke.points.length - 1; i++) {
          final p1 = stroke.points[i].toOffset();
          final p2 = stroke.points[i + 1].toOffset();

          final poly = Path()
            ..moveTo(p1.dx - bladeVec.dx, p1.dy - bladeVec.dy)
            ..lineTo(p1.dx + bladeVec.dx, p1.dy + bladeVec.dy)
            ..lineTo(p2.dx + bladeVec.dx, p2.dy + bladeVec.dy)
            ..lineTo(p2.dx - bladeVec.dx, p2.dy - bladeVec.dy)
            ..close();
          canvas.drawPath(poly, paint..style = PaintingStyle.fill);
        }
        break;

      case PenType.pencil:
        // Pencil: Variable width with fine stippling stroke
        final segments = BezierSplineCalculator.fitSpline(stroke.points, stroke.baseWidth);
        for (final seg in segments) {
          paint.strokeWidth = seg.startWidth;
          canvas.drawLine(seg.p0, seg.p1, paint..style = PaintingStyle.stroke);
        }
        break;

      default:
        // Ballpoint: Variable pressure Bézier curve
        final segments = BezierSplineCalculator.fitSpline(stroke.points, stroke.baseWidth);
        if (segments.isEmpty) return;

        for (final seg in segments) {
          final Path segPath = Path()
            ..moveTo(seg.p0.dx, seg.p0.dy)
            ..cubicTo(seg.c1.dx, seg.c1.dy, seg.c2.dx, seg.c2.dy, seg.p1.dx, seg.p1.dy);
          paint.strokeWidth = (seg.startWidth + seg.endWidth) / 2.0;
          canvas.drawPath(segPath, paint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant TileStrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentAudioTimecodeMs != currentAudioTimecodeMs;
  }
}

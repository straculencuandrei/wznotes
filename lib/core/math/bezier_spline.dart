import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/stroke_point.dart';

/// Cubic Bézier curve segment representation
class CubicSegment {
  final Offset p0;
  final Offset c1;
  final Offset c2;
  final Offset p1;
  final double startWidth;
  final double endWidth;

  const CubicSegment({
    required this.p0,
    required this.c1,
    required this.c2,
    required this.p1,
    required this.startWidth,
    required this.endWidth,
  });

  /// Evaluates position on the curve for parameter t in [0.0, 1.0]
  Offset pointAt(double t) {
    final double u = 1.0 - t;
    final double tt = t * t;
    final double uu = u * u;
    final double uuu = uu * u;
    final double ttt = tt * t;

    final double x = uuu * p0.dx + 3 * uu * t * c1.dx + 3 * u * tt * c2.dx + ttt * p1.dx;
    final double y = uuu * p0.dy + 3 * uu * t * c1.dy + 3 * u * tt * c2.dy + ttt * p1.dy;
    return Offset(x, y);
  }

  /// Computes tangent normal vector perpendicular to curve at parameter t
  Offset normalAt(double t) {
    final double u = 1.0 - t;
    // Derivative of cubic bezier: 3*(1-t)^2*(c1-p0) + 6*(1-t)*t*(c2-c1) + 3*t^2*(p1-c2)
    final double dx = 3 * u * u * (c1.dx - p0.dx) + 6 * u * t * (c2.dx - c1.dx) + 3 * t * t * (p1.dx - c2.dx);
    final double dy = 3 * u * u * (c1.dy - p0.dy) + 6 * u * t * (c2.dy - c1.dy) + 3 * t * t * (p1.dy - c2.dy);
    final double len = sqrt(dx * dx + dy * dy);
    if (len == 0) return const Offset(0, 1);
    return Offset(-dy / len, dx / len);
  }

  /// Evaluates interpolated width at parameter t
  double widthAt(double t) => startWidth + (endWidth - startWidth) * t;
}

/// Converts raw stylus discrete points into smooth Catmull-Rom derived Cubic Bézier splines
class BezierSplineCalculator {
  /// Generates smooth cubic bezier segments connecting all points in sequence
  static List<CubicSegment> fitSpline(List<StrokePoint> points, double baseWidth, {double pressureExponent = 1.2}) {
    if (points.length < 2) return [];

    final List<CubicSegment> segments = [];

    // Precalculate width for each point using smoothed pressure
    final List<double> widths = points.map((p) {
      final double pNorm = p.pressure.clamp(0.1, 1.0);
      return max(0.8, baseWidth * pow(pNorm, pressureExponent));
    }).toList();

    if (points.length == 2) {
      // Direct linear segment converted to cubic
      final p0 = points[0].toOffset();
      final p1 = points[1].toOffset();
      segments.add(CubicSegment(
        p0: p0,
        c1: Offset.lerp(p0, p1, 1 / 3)!,
        c2: Offset.lerp(p0, p1, 2 / 3)!,
        p1: p1,
        startWidth: widths[0],
        endWidth: widths[1],
      ));
      return segments;
    }

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = (i == 0) ? points[0].toOffset() : points[i - 1].toOffset();
      final Offset p1 = points[i].toOffset();
      final Offset p2 = points[i + 1].toOffset();
      final Offset p3 = (i + 2 < points.length) ? points[i + 2].toOffset() : p2;

      // Catmull-Rom to Cubic Bézier conversion
      // C1 = P1 + (P2 - P0) / 6
      // C2 = P2 - (P3 - P1) / 6
      final Offset c1 = p1 + (p2 - p0) / 6.0;
      final Offset c2 = p2 - (p3 - p1) / 6.0;

      segments.add(CubicSegment(
        p0: p1,
        c1: c1,
        c2: c2,
        p1: p2,
        startWidth: widths[i],
        endWidth: widths[i + 1],
      ));
    }

    return segments;
  }

  /// Builds a smooth variable-width outline Path from cubic segments
  static Path buildRibbonPath(List<CubicSegment> segments, {int samplesPerSegment = 8}) {
    if (segments.isEmpty) return Path();

    final List<Offset> leftBoundary = [];
    final List<Offset> rightBoundary = [];

    for (int s = 0; s < segments.length; s++) {
      final segment = segments[s];
      final int count = (s == segments.length - 1) ? samplesPerSegment + 1 : samplesPerSegment;

      for (int i = 0; i < count; i++) {
        final double t = i / samplesPerSegment;
        final Offset center = segment.pointAt(t);
        final Offset normal = segment.normalAt(t);
        final double halfWidth = segment.widthAt(t) / 2.0;

        leftBoundary.add(center + normal * halfWidth);
        rightBoundary.add(center - normal * halfWidth);
      }
    }

    final Path path = Path();
    if (leftBoundary.isEmpty) return path;

    // Start at first left point
    path.moveTo(leftBoundary.first.dx, leftBoundary.first.dy);

    // Follow left contour
    for (int i = 1; i < leftBoundary.length; i++) {
      path.lineTo(leftBoundary[i].dx, leftBoundary[i].dy);
    }

    // Add rounded end cap
    final Offset lastLeft = leftBoundary.last;
    final Offset lastRight = rightBoundary.last;
    path.arcToPoint(
      lastRight,
      radius: Radius.circular((lastLeft - lastRight).distance / 2.0),
      clockwise: true,
    );

    // Follow right contour backwards
    for (int i = rightBoundary.length - 2; i >= 0; i--) {
      path.lineTo(rightBoundary[i].dx, rightBoundary[i].dy);
    }

    // Add rounded start cap
    final Offset firstLeft = leftBoundary.first;
    final Offset firstRight = rightBoundary.first;
    path.arcToPoint(
      firstLeft,
      radius: Radius.circular((firstLeft - firstRight).distance / 2.0),
      clockwise: true,
    );

    path.close();
    return path;
  }
}

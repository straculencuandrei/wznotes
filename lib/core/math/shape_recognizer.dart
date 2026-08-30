import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/stroke_point.dart';

enum SnappedShapeType {
  none,
  line,
  circle,
  rectangle,
  triangle,
}

class SnappedShapeResult {
  final SnappedShapeType type;
  final List<StrokePoint> snappedPoints;
  final Rect? boundingBox;

  const SnappedShapeResult({
    required this.type,
    required this.snappedPoints,
    this.boundingBox,
  });

  bool get isRecognized => type != SnappedShapeType.none;
}

/// Geometric Shape Recognizer with Ramer-Douglas-Peucker reduction and circularity/aspect analysis
class ShapeRecognizer {
  /// Evaluates whether a completed stroke can be snapped to a perfect geometric primitive
  static SnappedShapeResult recognize(List<StrokePoint> rawPoints) {
    if (rawPoints.length < 5) {
      return SnappedShapeResult(type: SnappedShapeType.none, snappedPoints: rawPoints);
    }

    final List<Offset> offsets = rawPoints.map((p) => p.toOffset()).toList();
    final double basePressure = rawPoints.map((p) => p.pressure).reduce((a, b) => a + b) / rawPoints.length;

    // 1. Check for Straight Line
    final straightLine = _checkStraightLine(offsets, rawPoints, basePressure);
    if (straightLine != null) return straightLine;

    // 2. Check if the stroke is closed (start and end points are near each other)
    final double loopDistance = (offsets.first - offsets.last).distance;
    final Rect aabb = _calculateBoundingBox(offsets);
    final double perimeter = _calculatePerimeter(offsets);
    final double area = _calculatePolygonArea(offsets);

    final bool isClosed = loopDistance < max(35.0, aabb.longestSide * 0.25);

    if (isClosed && area > 50.0) {
      // 2a. Check for Circle / Ellipse
      // Isoperimetric quotient: Q = 4 * pi * Area / (Perimeter^2). For perfect circle Q = 1.0
      final double circularity = (4 * pi * area) / (perimeter * perimeter);
      if (circularity > 0.68) {
        return _buildCircle(aabb, rawPoints.first.timestampMs, basePressure);
      }

      // 2b. Simplify with Ramer-Douglas-Peucker for Polygon Detection
      final List<Offset> simplified = _rdpSimplify(offsets, epsilon: aabb.longestSide * 0.08);

      // Rectangle / Square detection (4 corners + closing point = 4 or 5 vertices)
      if (simplified.length >= 4 && simplified.length <= 6) {
        return _buildRectangle(aabb, rawPoints.first.timestampMs, basePressure);
      }

      // Triangle detection (3 corners + closing point = 3 or 4 vertices)
      if (simplified.length == 3 || simplified.length == 4) {
        return _buildPolygon(simplified, rawPoints.first.timestampMs, basePressure, SnappedShapeType.triangle);
      }
    }

    return SnappedShapeResult(type: SnappedShapeType.none, snappedPoints: rawPoints);
  }

  static SnappedShapeResult? _checkStraightLine(List<Offset> offsets, List<StrokePoint> rawPoints, double pressure) {
    final Offset start = offsets.first;
    final Offset end = offsets.last;
    final double directDistance = (end - start).distance;
    if (directDistance < 20.0) return null;

    // Calculate maximum perpendicular deviation from the direct line
    double maxDeviation = 0.0;
    for (final pt in offsets) {
      final double dev = _pointToLineDistance(pt, start, end);
      if (dev > maxDeviation) maxDeviation = dev;
    }

    // If max deviation is within 6% of line length or < 12 points, it's a straight line!
    if (maxDeviation < max(12.0, directDistance * 0.06)) {
      // Snap to horizontal or vertical if angle is within 5 degrees
      Offset snappedEnd = end;
      final double angle = atan2(end.dy - start.dy, end.dx - start.dx);
      final double absAngle = angle.abs();

      // Near horizontal (0 or pi)
      if (absAngle < 0.087 || (pi - absAngle) < 0.087) {
        snappedEnd = Offset(end.dx, start.dy);
      }
      // Near vertical (pi/2)
      else if ((absAngle - pi / 2).abs() < 0.087) {
        snappedEnd = Offset(start.dx, end.dy);
      }

      final List<StrokePoint> points = [
        StrokePoint(x: start.dx, y: start.dy, pressure: pressure, timestampMs: rawPoints.first.timestampMs),
        StrokePoint(x: snappedEnd.dx, y: snappedEnd.dy, pressure: pressure, timestampMs: rawPoints.last.timestampMs),
      ];

      return SnappedShapeResult(type: SnappedShapeType.line, snappedPoints: points);
    }
    return null;
  }

  static SnappedShapeResult _buildCircle(Rect aabb, int timestamp, double pressure) {
    final Offset center = aabb.center;
    final double radiusX = aabb.width / 2.0;
    final double radiusY = aabb.height / 2.0;

    // If almost equal width and height, make it a true perfect circle
    final double avgRadius = (radiusX + radiusY) / 2.0;
    final bool isTrueCircle = (radiusX - radiusY).abs() / avgRadius < 0.15;
    final double rx = isTrueCircle ? avgRadius : radiusX;
    final double ry = isTrueCircle ? avgRadius : radiusY;

    final List<StrokePoint> points = [];
    const int sampleCount = 36;
    for (int i = 0; i <= sampleCount; i++) {
      final double angle = (i / sampleCount) * 2 * pi;
      points.add(StrokePoint(
        x: center.dx + rx * cos(angle),
        y: center.dy + ry * sin(angle),
        pressure: pressure,
        timestampMs: timestamp + (i * 10),
      ));
    }

    return SnappedShapeResult(type: SnappedShapeType.circle, snappedPoints: points, boundingBox: aabb);
  }

  static SnappedShapeResult _buildRectangle(Rect aabb, int timestamp, double pressure) {
    final List<StrokePoint> points = [
      StrokePoint(x: aabb.left, y: aabb.top, pressure: pressure, timestampMs: timestamp),
      StrokePoint(x: aabb.right, y: aabb.top, pressure: pressure, timestampMs: timestamp + 20),
      StrokePoint(x: aabb.right, y: aabb.bottom, pressure: pressure, timestampMs: timestamp + 40),
      StrokePoint(x: aabb.left, y: aabb.bottom, pressure: pressure, timestampMs: timestamp + 60),
      StrokePoint(x: aabb.left, y: aabb.top, pressure: pressure, timestampMs: timestamp + 80),
    ];
    return SnappedShapeResult(type: SnappedShapeType.rectangle, snappedPoints: points, boundingBox: aabb);
  }

  static SnappedShapeResult _buildPolygon(List<Offset> vertices, int timestamp, double pressure, SnappedShapeType type) {
    final List<StrokePoint> points = [];
    for (int i = 0; i < vertices.length; i++) {
      points.add(StrokePoint(
        x: vertices[i].dx,
        y: vertices[i].dy,
        pressure: pressure,
        timestampMs: timestamp + (i * 25),
      ));
    }
    // Close polygon
    if (vertices.isNotEmpty && (vertices.first - vertices.last).distance > 2.0) {
      points.add(StrokePoint(
        x: vertices.first.dx,
        y: vertices.first.dy,
        pressure: pressure,
        timestampMs: timestamp + (vertices.length * 25),
      ));
    }
    return SnappedShapeResult(type: type, snappedPoints: points);
  }

  // --- Geometry Helpers ---

  static Rect _calculateBoundingBox(List<Offset> pts) {
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static double _calculatePerimeter(List<Offset> pts) {
    double p = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      p += (pts[i + 1] - pts[i]).distance;
    }
    return p;
  }

  static double _calculatePolygonArea(List<Offset> pts) {
    double area = 0.0;
    for (int i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      area += pts[i].dx * pts[j].dy;
      area -= pts[j].dx * pts[i].dy;
    }
    return (area / 2.0).abs();
  }

  static double _pointToLineDistance(Offset pt, Offset a, Offset b) {
    final double len = (b - a).distance;
    if (len == 0) return (pt - a).distance;
    return ((pt.dx - a.dx) * (b.dy - a.dy) - (pt.dy - a.dy) * (b.dx - a.dx)).abs() / len;
  }

  static List<Offset> _rdpSimplify(List<Offset> points, {required double epsilon}) {
    if (points.length < 3) return points;

    double maxDist = 0.0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = _pointToLineDistance(points[i], points.first, points.last);
      if (dist > maxDist) {
        maxDist = dist;
        index = i;
      }
    }

    if (maxDist > epsilon) {
      final recResults1 = _rdpSimplify(points.sublist(0, index + 1), epsilon: epsilon);
      final recResults2 = _rdpSimplify(points.sublist(index), epsilon: epsilon);
      return [...recResults1.sublist(0, recResults1.length - 1), ...recResults2];
    } else {
      return [points.first, points.last];
    }
  }
}

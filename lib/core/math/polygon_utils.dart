import 'package:flutter/material.dart';
import '../../domain/models/vector_stroke.dart';

/// Geometric utilities for Lasso Selection, Ray-Casting Point-in-Polygon hit-testing
class PolygonUtils {
  /// Jordan Curve / Ray-Casting algorithm: Tests if a single point (x, y) lies inside a closed polygon
  static bool isPointInsidePolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    final int count = polygon.length;

    for (int i = 0, j = count - 1; i < count; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;

      final bool intersect = ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }

    return inside;
  }

  /// Determines if a VectorStroke is enclosed by a drawn lasso boundary polygon
  static bool isStrokeInsideLasso(VectorStroke stroke, List<Offset> lassoPolygon) {
    if (stroke.points.isEmpty || lassoPolygon.length < 3) return false;

    // Fast check 1: Stroke Bounding Box center
    final Rect bounds = stroke.calculateBounds();
    if (isPointInsidePolygon(bounds.center, lassoPolygon)) {
      return true;
    }

    // Check 2: Sample points along stroke (check if >= 50% of vertices are inside)
    int insideCount = 0;
    final int step = (stroke.points.length / 8).ceil().clamp(1, 10);
    int totalSampled = 0;

    for (int i = 0; i < stroke.points.length; i += step) {
      totalSampled++;
      if (isPointInsidePolygon(stroke.points[i].toOffset(), lassoPolygon)) {
        insideCount++;
      }
    }

    return (insideCount / totalSampled) >= 0.5;
  }

  /// Calculates aggregated Axis-Aligned Bounding Box (AABB) for a group of strokes
  static Rect? calculateAggregatedBounds(List<VectorStroke> strokes) {
    if (strokes.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final stroke in strokes) {
      final bounds = stroke.calculateBounds();
      if (bounds.left < minX) minX = bounds.left;
      if (bounds.top < minY) minY = bounds.top;
      if (bounds.right > maxX) maxX = bounds.right;
      if (bounds.bottom > maxY) maxY = bounds.bottom;
    }

    if (minX == double.infinity) return null;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

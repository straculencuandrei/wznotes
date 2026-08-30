import 'package:flutter/material.dart';
import '../../core/constants/canvas_dimensions.dart';
import 'vector_stroke.dart';

/// Represents a vertical spatial tile chunk along the infinite canvas
class SpatialTile {
  final int index;
  final double topY;
  final double bottomY;
  final List<VectorStroke> strokes;

  SpatialTile({
    required this.index,
    required this.topY,
    required this.bottomY,
    List<VectorStroke>? strokes,
  }) : strokes = strokes ?? [];

  Rect get bounds => Rect.fromLTRB(0, topY, CanvasDimensions.defaultDocumentWidth, bottomY);

  /// Helper to calculate the tile index for a given Y coordinate
  static int tileIndexForY(double y) {
    if (y < 0) return 0;
    return (y / CanvasDimensions.spatialChunkHeight).floor();
  }

  /// Calculates top Y coordinate for a tile index
  static double topYForIndex(int index) {
    return index * CanvasDimensions.spatialChunkHeight;
  }
}

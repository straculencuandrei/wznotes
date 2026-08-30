import 'package:flutter/material.dart';
import 'stroke_point.dart';
import 'pen_tool.dart';

/// Complete Vector Stroke data structure
class VectorStroke {
  final String id;
  final PenType toolType;
  final Color color;
  final double baseWidth;
  final double opacity;
  final BlendMode blendMode;
  final int audioTimecodeMs; // Synchronized audio time offset in ms (or -1 if none)
  final bool isShapeSnapped;
  final String? anchorBlockId; // If anchored to a specific text paragraph
  final List<StrokePoint> points;

  // Cached Bounds for Fast Culling & Spatial Indexing
  Rect? _cachedBounds;

  VectorStroke({
    required this.id,
    required this.toolType,
    required this.color,
    required this.baseWidth,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    this.audioTimecodeMs = -1,
    this.isShapeSnapped = false,
    this.anchorBlockId,
    required this.points,
  });

  /// Computes and caches Axis-Aligned Bounding Box (AABB)
  Rect calculateBounds() {
    if (_cachedBounds != null) return _cachedBounds!;
    if (points.isEmpty) return Rect.zero;

    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final double padding = baseWidth * 2.0;
    _cachedBounds = Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
    return _cachedBounds!;
  }

  /// Translates stroke points by delta (dx, dy) during lasso movement
  VectorStroke translate(Offset delta) {
    return copyWith(
      points: points
          .map((p) => p.copyWith(x: p.x + delta.dx, y: p.y + delta.dy))
          .toList(),
    );
  }

  /// Scales stroke points relative to an anchor origin during lasso transform
  VectorStroke scale(double scaleFactor, Offset origin) {
    return copyWith(
      baseWidth: baseWidth * scaleFactor,
      points: points.map((p) {
        final double nx = origin.dx + (p.x - origin.dx) * scaleFactor;
        final double ny = origin.dy + (p.y - origin.dy) * scaleFactor;
        return p.copyWith(x: nx, y: ny);
      }).toList(),
    );
  }

  VectorStroke copyWith({
    String? id,
    PenType? toolType,
    Color? color,
    double? baseWidth,
    double? opacity,
    BlendMode? blendMode,
    int? audioTimecodeMs,
    bool? isShapeSnapped,
    String? anchorBlockId,
    List<StrokePoint>? points,
  }) {
    return VectorStroke(
      id: id ?? this.id,
      toolType: toolType ?? this.toolType,
      color: color ?? this.color,
      baseWidth: baseWidth ?? this.baseWidth,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      audioTimecodeMs: audioTimecodeMs ?? this.audioTimecodeMs,
      isShapeSnapped: isShapeSnapped ?? this.isShapeSnapped,
      anchorBlockId: anchorBlockId ?? this.anchorBlockId,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'toolType': toolType.name,
        'color': '#${color.value.toRadixString(16).padLeft(8, '0')}',
        'baseWidth': double.parse(baseWidth.toStringAsFixed(2)),
        'opacity': double.parse(opacity.toStringAsFixed(2)),
        'blendMode': blendMode.name,
        'audioTimecodeMs': audioTimecodeMs,
        'isShapeSnapped': isShapeSnapped,
        if (anchorBlockId != null) 'anchorBlockId': anchorBlockId,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory VectorStroke.fromJson(Map<String, dynamic> json) {
    final colorHex = json['color'] as String;
    final cleanHex = colorHex.replaceAll('#', '');
    final colorInt = int.parse(cleanHex, radix: 16);

    return VectorStroke(
      id: json['id'] as String,
      toolType: PenType.values.firstWhere(
        (t) => t.name == json['toolType'],
        orElse: () => PenType.ballpoint,
      ),
      color: Color(colorInt),
      baseWidth: (json['baseWidth'] as num).toDouble(),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      blendMode: BlendMode.values.firstWhere(
        (b) => b.name == json['blendMode'],
        orElse: () => BlendMode.srcOver,
      ),
      audioTimecodeMs: (json['audioTimecodeMs'] as num?)?.toInt() ?? -1,
      isShapeSnapped: (json['isShapeSnapped'] as bool?) ?? false,
      anchorBlockId: json['anchorBlockId'] as String?,
      points: (json['points'] as List)
          .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

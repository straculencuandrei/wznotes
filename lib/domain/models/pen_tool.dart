import 'package:flutter/material.dart';

enum PenType {
  ballpoint,
  calligraphy,
  highlighter,
  pencil,
  eraser,
  lasso,
}

extension PenTypeExtension on PenType {
  String get displayName {
    switch (this) {
      case PenType.ballpoint:
        return 'Ballpoint';
      case PenType.calligraphy:
        return 'Calligraphy';
      case PenType.highlighter:
        return 'Highlighter';
      case PenType.pencil:
        return 'Pencil';
      case PenType.eraser:
        return 'Eraser';
      case PenType.lasso:
        return 'Lasso';
    }
  }

  BlendMode get defaultBlendMode {
    switch (this) {
      case PenType.highlighter:
        return BlendMode.multiply;
      default:
        return BlendMode.srcOver;
    }
  }

  double get defaultOpacity {
    switch (this) {
      case PenType.highlighter:
        return 0.45;
      case PenType.pencil:
        return 0.85;
      default:
        return 1.0;
    }
  }

  double get defaultBaseWidth {
    switch (this) {
      case PenType.ballpoint:
        return 2.5;
      case PenType.calligraphy:
        return 4.5;
      case PenType.highlighter:
        return 22.0;
      case PenType.pencil:
        return 2.0;
      case PenType.eraser:
        return 20.0;
      case PenType.lasso:
        return 1.5;
    }
  }
}

/// Active Pen Tool Configuration
class PenToolConfig {
  final PenType type;
  final Color color;
  final double baseWidth;
  final double opacity;
  final BlendMode blendMode;
  final double calligraphyAngle; // Chisel nib angle in radians (default pi/4 = 45 deg)

  const PenToolConfig({
    required this.type,
    required this.color,
    required this.baseWidth,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    this.calligraphyAngle = 0.785398, // 45 degrees
  });

  PenToolConfig copyWith({
    PenType? type,
    Color? color,
    double? baseWidth,
    double? opacity,
    BlendMode? blendMode,
    double? calligraphyAngle,
  }) {
    return PenToolConfig(
      type: type ?? this.type,
      color: color ?? this.color,
      baseWidth: baseWidth ?? this.baseWidth,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      calligraphyAngle: calligraphyAngle ?? this.calligraphyAngle,
    );
  }
}

import 'package:flutter/material.dart';

/// Single precision touch/stylus coordinate with pressure, tilt, orientation, and timestamp
class StrokePoint {
  final double x;
  final double y;
  final double pressure; // Normalized in [0.0, 1.0]
  final int timestampMs;
  final double tilt; // Stylus tilt angle in radians
  final double orientation; // Stylus barrel orientation angle in radians

  const StrokePoint({
    required this.x,
    required this.y,
    required this.pressure,
    required this.timestampMs,
    this.tilt = 0.0,
    this.orientation = 0.0,
  });

  Offset toOffset() => Offset(x, y);

  StrokePoint copyWith({
    double? x,
    double? y,
    double? pressure,
    int? timestampMs,
    double? tilt,
    double? orientation,
  }) {
    return StrokePoint(
      x: x ?? this.x,
      y: y ?? this.y,
      pressure: pressure ?? this.pressure,
      timestampMs: timestampMs ?? this.timestampMs,
      tilt: tilt ?? this.tilt,
      orientation: orientation ?? this.orientation,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': double.parse(x.toStringAsFixed(2)),
        'y': double.parse(y.toStringAsFixed(2)),
        'p': double.parse(pressure.toStringAsFixed(3)),
        't': timestampMs,
        if (tilt != 0.0) 'tilt': double.parse(tilt.toStringAsFixed(2)),
        if (orientation != 0.0) 'or': double.parse(orientation.toStringAsFixed(2)),
      };

  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pressure: (json['p'] as num?)?.toDouble() ?? 0.5,
      timestampMs: (json['t'] as num?)?.toInt() ?? 0,
      tilt: (json['tilt'] as num?)?.toDouble() ?? 0.0,
      orientation: (json['or'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

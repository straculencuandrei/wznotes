import 'dart:math';
import 'package:flutter/material.dart';

/// Low-pass Exponential Moving Average (EMA) and Velocity filter for raw stylus input
class StylusPressureFilter {
  final double alpha; // Smoothing factor between 0.0 (max smooth) and 1.0 (raw)
  double? _lastFilteredPressure;
  Offset? _lastPosition;
  int? _lastTimestampMs;
  double _lastVelocity = 0.0;

  StylusPressureFilter({this.alpha = 0.35});

  /// Feeds a new raw stylus sample and returns the smoothed pressure in range [0.05, 1.0]
  double filter({
    required Offset position,
    required double rawPressure,
    required int timestampMs,
  }) {
    // If device doesn't supply variable pressure (e.g. mouse or basic capacitive stylus),
    // synthesize pressure dynamically based on movement velocity!
    double inputPressure = rawPressure;

    if (_lastPosition != null && _lastTimestampMs != null) {
      final double distance = (position - _lastPosition!).distance;
      final int dt = max(1, timestampMs - _lastTimestampMs!);
      final double velocity = distance / dt; // points per millisecond

      // Velocity smoothing
      _lastVelocity = 0.3 * velocity + 0.7 * _lastVelocity;

      if (rawPressure <= 0.0 || rawPressure == 1.0) {
        // Synthesized pressure: faster stroke = slightly thinner, slower = thicker
        final double speedFactor = (1.0 - (_lastVelocity * 0.4)).clamp(0.2, 0.85);
        inputPressure = speedFactor;
      }
    }

    _lastPosition = position;
    _lastTimestampMs = timestampMs;

    if (_lastFilteredPressure == null) {
      _lastFilteredPressure = inputPressure;
      return inputPressure;
    }

    final double smoothed = alpha * inputPressure + (1.0 - alpha) * _lastFilteredPressure!;
    _lastFilteredPressure = smoothed;
    return smoothed.clamp(0.05, 1.0);
  }

  /// Current smoothed velocity in pixels/millisecond
  double get currentVelocity => _lastVelocity;

  /// Resets filter state when a new stroke begins
  void reset() {
    _lastFilteredPressure = null;
    _lastPosition = null;
    _lastTimestampMs = null;
    _lastVelocity = 0.0;
  }
}

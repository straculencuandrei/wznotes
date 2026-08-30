import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/canvas_dimensions.dart';

class CanvasViewportState {
  final double scale;
  final Offset panOffset;
  final double canvasHeight;
  final bool isTypewriterMode;
  final double typewriterScrollOffset;

  const CanvasViewportState({
    this.scale = 1.0,
    this.panOffset = Offset.zero,
    this.canvasHeight = CanvasDimensions.initialInfiniteHeight,
    this.isTypewriterMode = false,
    this.typewriterScrollOffset = 0.0,
  });

  CanvasViewportState copyWith({
    double? scale,
    Offset? panOffset,
    double? canvasHeight,
    bool? isTypewriterMode,
    double? typewriterScrollOffset,
  }) {
    return CanvasViewportState(
      scale: scale ?? this.scale,
      panOffset: panOffset ?? this.panOffset,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      isTypewriterMode: isTypewriterMode ?? this.isTypewriterMode,
      typewriterScrollOffset: typewriterScrollOffset ?? this.typewriterScrollOffset,
    );
  }
}

class CanvasViewportNotifier extends StateNotifier<CanvasViewportState> {
  CanvasViewportNotifier() : super(const CanvasViewportState());

  void setScale(double newScale) {
    final clamped = newScale.clamp(CanvasDimensions.minZoom, CanvasDimensions.maxZoom);
    state = state.copyWith(scale: clamped);
  }

  void updatePan(Offset delta) {
    state = state.copyWith(panOffset: state.panOffset + delta);
  }

  /// Automatically expands infinite canvas downwards when approaching the bottom
  void checkAndExpandCanvas(double currentScrollY) {
    if (currentScrollY > state.canvasHeight - CanvasDimensions.autoExpandThreshold) {
      final double newHeight = state.canvasHeight + CanvasDimensions.spatialChunkHeight;
      state = state.copyWith(canvasHeight: newHeight);
    }
  }

  void toggleTypewriterMode() {
    state = state.copyWith(isTypewriterMode: !state.isTypewriterMode);
  }

  void setTypewriterOffset(double offset) {
    state = state.copyWith(typewriterScrollOffset: offset);
  }

  void resetViewport() {
    state = state.copyWith(scale: 1.0, panOffset: Offset.zero);
  }
}

final canvasViewportProvider = StateNotifierProvider<CanvasViewportNotifier, CanvasViewportState>((ref) {
  return CanvasViewportNotifier();
});

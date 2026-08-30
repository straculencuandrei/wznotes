import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/math/pressure_filter.dart';
import '../../core/math/shape_recognizer.dart';
import '../../core/math/polygon_utils.dart';
import '../../domain/models/stroke_point.dart';
import '../../domain/models/vector_stroke.dart';
import '../../domain/models/pen_tool.dart';
import 'document_controller.dart';

class InkingState {
  final PenToolConfig toolConfig;
  final List<StrokePoint> activeStrokePoints;
  final List<Offset> activeLassoPolygon;
  final List<String> selectedStrokeIds;
  final Rect? lassoBoundingBox;
  final bool isDrawing;
  final bool isInkingMode; // true = inking with stylus/touch, false = typing/text focus

  const InkingState({
    required this.toolConfig,
    this.activeStrokePoints = const [],
    this.activeLassoPolygon = const [],
    this.selectedStrokeIds = const [],
    this.lassoBoundingBox,
    this.isDrawing = false,
    this.isInkingMode = false, // Keyboard writing is the primary experience!
  });

  InkingState copyWith({
    PenToolConfig? toolConfig,
    List<StrokePoint>? activeStrokePoints,
    List<Offset>? activeLassoPolygon,
    List<String>? selectedStrokeIds,
    Rect? lassoBoundingBox,
    bool? isDrawing,
    bool? isInkingMode,
    bool clearBoundingBox = false,
  }) {
    return InkingState(
      toolConfig: toolConfig ?? this.toolConfig,
      activeStrokePoints: activeStrokePoints ?? this.activeStrokePoints,
      activeLassoPolygon: activeLassoPolygon ?? this.activeLassoPolygon,
      selectedStrokeIds: selectedStrokeIds ?? this.selectedStrokeIds,
      lassoBoundingBox: clearBoundingBox ? null : (lassoBoundingBox ?? this.lassoBoundingBox),
      isDrawing: isDrawing ?? this.isDrawing,
      isInkingMode: isInkingMode ?? this.isInkingMode,
    );
  }
}

class InkingNotifier extends StateNotifier<InkingState> {
  final Ref ref;
  final StylusPressureFilter _pressureFilter = StylusPressureFilter(alpha: 0.35);
  Timer? _holdToSnapTimer;
  Offset? _lastStylusPoint;

  InkingNotifier(this.ref)
      : super(const InkingState(
          toolConfig: PenToolConfig(
            type: PenType.ballpoint,
            color: AppColors.primaryDarkInk,
            baseWidth: 2.5,
          ),
        ));

  void setPenType(PenType type) {
    state = state.copyWith(
      toolConfig: state.toolConfig.copyWith(
        type: type,
        baseWidth: type.defaultBaseWidth,
        opacity: type.defaultOpacity,
        blendMode: type.defaultBlendMode,
      ),
      clearBoundingBox: true,
      selectedStrokeIds: [],
    );
  }

  void setPenColor(Color color) {
    state = state.copyWith(toolConfig: state.toolConfig.copyWith(color: color));
    if (state.selectedStrokeIds.isNotEmpty) {
      ref.read(documentProvider.notifier).recolorSelectedStrokes(state.selectedStrokeIds, color);
    }
  }

  void setPenWidth(double width) {
    state = state.copyWith(toolConfig: state.toolConfig.copyWith(baseWidth: width));
  }

  void toggleInkingMode(bool inking) {
    state = state.copyWith(isInkingMode: inking);
  }

  // --- Stylus Input Pipeline ---

  void onPointerDown(Offset canvasPos, double rawPressure, int timestampMs) {
    _holdToSnapTimer?.cancel();
    _pressureFilter.reset();
    _lastStylusPoint = canvasPos;

    final double smoothedPressure = _pressureFilter.filter(
      position: canvasPos,
      rawPressure: rawPressure,
      timestampMs: timestampMs,
    );

    final startPoint = StrokePoint(
      x: canvasPos.dx,
      y: canvasPos.dy,
      pressure: smoothedPressure,
      timestampMs: timestampMs,
    );

    if (state.toolConfig.type == PenType.lasso) {
      state = state.copyWith(
        isDrawing: true,
        activeLassoPolygon: [canvasPos],
        clearBoundingBox: true,
        selectedStrokeIds: [],
      );
    } else {
      state = state.copyWith(
        isDrawing: true,
        activeStrokePoints: [startPoint],
      );

      // Start hold-to-snap timer (450ms still hold triggers shape recognition)
      _holdToSnapTimer = Timer(const Duration(milliseconds: 450), () {
        _triggerHoldToSnap();
      });
    }
  }

  void onPointerMove(Offset canvasPos, double rawPressure, int timestampMs) {
    if (!state.isDrawing) return;

    if (_lastStylusPoint != null && (canvasPos - _lastStylusPoint!).distance > 6.0) {
      // Movement detected, reset hold-to-snap timer
      _holdToSnapTimer?.cancel();
      _holdToSnapTimer = Timer(const Duration(milliseconds: 450), () {
        _triggerHoldToSnap();
      });
    }
    _lastStylusPoint = canvasPos;

    if (state.toolConfig.type == PenType.lasso) {
      state = state.copyWith(
        activeLassoPolygon: [...state.activeLassoPolygon, canvasPos],
      );
    } else {
      final double smoothedPressure = _pressureFilter.filter(
        position: canvasPos,
        rawPressure: rawPressure,
        timestampMs: timestampMs,
      );

      final newPoint = StrokePoint(
        x: canvasPos.dx,
        y: canvasPos.dy,
        pressure: smoothedPressure,
        timestampMs: timestampMs,
      );

      state = state.copyWith(
        activeStrokePoints: [...state.activeStrokePoints, newPoint],
      );
    }
  }

  void onPointerUp() {
    _holdToSnapTimer?.cancel();
    if (!state.isDrawing) return;

    if (state.toolConfig.type == PenType.lasso) {
      _finalizeLassoSelection();
    } else {
      _finalizeStroke();
    }
  }

  void _triggerHoldToSnap() {
    if (state.activeStrokePoints.length < 5) return;
    final shapeResult = ShapeRecognizer.recognize(state.activeStrokePoints);
    if (shapeResult.isRecognized) {
      state = state.copyWith(
        activeStrokePoints: shapeResult.snappedPoints,
      );
    }
  }

  void _finalizeStroke() {
    if (state.activeStrokePoints.length >= 2) {
      final newStroke = VectorStroke(
        id: const Uuid().v4(),
        toolType: state.toolConfig.type,
        color: state.toolConfig.color,
        baseWidth: state.toolConfig.baseWidth,
        opacity: state.toolConfig.opacity,
        blendMode: state.toolConfig.blendMode,
        points: List.from(state.activeStrokePoints),
      );

      // Commit to document model
      ref.read(documentProvider.notifier).addStroke(newStroke);
    }

    state = state.copyWith(
      isDrawing: false,
      activeStrokePoints: [],
    );
  }

  void _finalizeLassoSelection() {
    final lassoLoop = List<Offset>.from(state.activeLassoPolygon);
    final allStrokes = ref.read(documentProvider).strokes;

    final List<String> selected = [];
    for (final stroke in allStrokes) {
      if (PolygonUtils.isStrokeInsideLasso(stroke, lassoLoop)) {
        selected.add(stroke.id);
      }
    }

    final selectedStrokes = allStrokes.where((s) => selected.contains(s.id)).toList();
    final Rect? boundingBox = PolygonUtils.calculateAggregatedBounds(selectedStrokes);

    state = state.copyWith(
      isDrawing: false,
      activeLassoPolygon: [],
      selectedStrokeIds: selected,
      lassoBoundingBox: boundingBox,
    );
  }

  void deleteSelectedStrokes() {
    if (state.selectedStrokeIds.isEmpty) return;
    ref.read(documentProvider.notifier).deleteStrokes(state.selectedStrokeIds);
    state = state.copyWith(
      selectedStrokeIds: [],
      clearBoundingBox: true,
    );
  }

  void duplicateSelectedStrokes() {
    if (state.selectedStrokeIds.isEmpty) return;
    ref.read(documentProvider.notifier).duplicateStrokes(state.selectedStrokeIds, const Offset(30, 30));
  }

  @override
  void dispose() {
    _holdToSnapTimer?.cancel();
    super.dispose();
  }
}

final inkingProvider = StateNotifierProvider<InkingNotifier, InkingState>((ref) {
  return InkingNotifier(ref);
});

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/pen_tool.dart';
import '../controllers/infinite_canvas_controller.dart';
import '../controllers/inking_controller.dart';
import '../controllers/document_controller.dart';
import '../controllers/editor_formatting_bridge.dart';
import '../widgets/infinite_rich_text_layer.dart';
import 'tile_stroke_painter.dart';
import 'active_stroke_painter.dart';
import 'lasso_painter.dart';
import '../../core/diagnostics/performance_benchmark.dart';

/// Pure AMOLED Keyboard & Inking Viewport
class InfiniteCanvasViewport extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const InfiniteCanvasViewport({
    super.key,
    required this.scrollController,
  });

  @override
  ConsumerState<InfiniteCanvasViewport> createState() => _InfiniteCanvasViewportState();
}

class _InfiniteCanvasViewportState extends ConsumerState<InfiniteCanvasViewport> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    ref.read(canvasViewportProvider.notifier).checkAndExpandCanvas(widget.scrollController.offset);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkService.measure('canvas_viewport_build', () {
      final strokes = ref.watch(documentProvider.select((d) => d.strokes));
      final inkingState = ref.watch(inkingProvider);
      final inkingNotifier = ref.read(inkingProvider.notifier);
      final double screenWidth = MediaQuery.sizeOf(context).width;
      final double screenHeight = MediaQuery.sizeOf(context).height;
      final double docWidth = screenWidth < 820.0 ? screenWidth : 820.0;

      return Container(
        color: Colors.transparent,
        child: PerformanceProbeWidget(
          tag: 'canvas_viewport',
          child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: inkingState.isInkingMode && inkingState.isDrawing
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 450.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (!inkingState.isInkingMode) {
                final bridge = ref.read(editorFormattingBridgeProvider);
                if (bridge.bodyController != null && bridge.bodyFocusNode != null) {
                  bridge.bodyFocusNode!.requestFocus();
                  bridge.bodyController!.selection = TextSelection.collapsed(offset: bridge.bodyController!.text.length);
                }
              }
            },
            child: Container(
              width: docWidth,
              constraints: BoxConstraints(minHeight: screenHeight),
              color: Colors.transparent,
              child: Stack(
                children: [
                  // 1. Keyboard-First Rich Text Layer (Always interactable unless stylus inking is active)
                  IgnorePointer(
                    ignoring: inkingState.isInkingMode,
                    child: InfiniteRichTextLayer(width: docWidth),
                  ),

                // 2. Committed Inking Vector Strokes (Transparent overlay)
                if (strokes.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: TileStrokePainter(strokes: strokes),
                        ),
                      ),
                    ),
                  ),

                // 3. Stylus Gesture Layer (Only active when in inking mode)
                if (inkingState.isInkingMode)
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (PointerDownEvent event) {
                        if (event.kind == PointerDeviceKind.invertedStylus) {
                          inkingNotifier.setPenType(PenType.eraser);
                        }
                        inkingNotifier.onPointerDown(
                          event.localPosition,
                          event.pressure,
                          DateTime.now().millisecondsSinceEpoch,
                        );
                      },
                      onPointerMove: (PointerMoveEvent event) {
                        inkingNotifier.onPointerMove(
                          event.localPosition,
                          event.pressure,
                          DateTime.now().millisecondsSinceEpoch,
                        );
                      },
                      onPointerUp: (_) => inkingNotifier.onPointerUp(),
                      child: Stack(
                        children: [
                          if (inkingState.isDrawing && inkingState.activeStrokePoints.isNotEmpty)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: ActiveStrokePainter(
                                  points: inkingState.activeStrokePoints,
                                  toolConfig: inkingState.toolConfig,
                                ),
                              ),
                            ),
                          if (inkingState.activeLassoPolygon.isNotEmpty || inkingState.lassoBoundingBox != null)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: LassoPainter(
                                  lassoPolygon: inkingState.activeLassoPolygon,
                                  boundingBox: inkingState.lassoBoundingBox,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
    });
  }
}

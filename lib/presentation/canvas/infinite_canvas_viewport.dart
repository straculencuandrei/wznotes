import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/canvas_dimensions.dart';
import '../../domain/models/pen_tool.dart';
import '../controllers/infinite_canvas_controller.dart';
import '../controllers/inking_controller.dart';
import '../controllers/document_controller.dart';
import '../widgets/infinite_rich_text_layer.dart';
import 'tile_stroke_painter.dart';
import 'active_stroke_painter.dart';
import 'lasso_painter.dart';

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
    final viewportState = ref.watch(canvasViewportProvider);
    final doc = ref.watch(documentProvider);
    final inkingState = ref.watch(inkingProvider);
    final inkingNotifier = ref.read(inkingProvider.notifier);

    const double docWidth = CanvasDimensions.defaultDocumentWidth;
    final double docHeight = viewportState.canvasHeight;

    return Container(
      color: AppColors.amoledBlack,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: inkingState.isInkingMode && inkingState.isDrawing
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            width: docWidth,
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            color: AppColors.amoledBlack,
            child: Stack(
              children: [
                // 1. Keyboard-First Rich Text Layer (Always interactable unless stylus inking is active)
                IgnorePointer(
                  ignoring: inkingState.isInkingMode,
                  child: InfiniteRichTextLayer(width: docWidth),
                ),

                // 2. Committed Inking Vector Strokes (Transparent overlay)
                if (doc.strokes.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: TileStrokePainter(strokes: doc.strokes),
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
    );
  }
}

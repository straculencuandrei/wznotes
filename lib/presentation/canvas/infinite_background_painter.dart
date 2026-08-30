import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/canvas_template.dart';

/// Procedural background template painter for infinite continuous canvas with Dark Mode support
class InfiniteBackgroundPainter extends CustomPainter {
  final CanvasTemplate template;
  final double width;
  final double height;
  final bool isDarkMode;

  const InfiniteBackgroundPainter({
    required this.template,
    required this.width,
    required this.height,
    this.isDarkMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill solid paper background
    final Color paperColor = isDarkMode ? AppColors.darkPaper : template.backgroundColor;
    final bgPaint = Paint()..color = paperColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    if (template.type == CanvasTemplateType.blank) return;

    final Color effectiveLineColor = isDarkMode ? AppColors.darkRuledLine : template.lineColor;
    final linePaint = Paint()
      ..color = effectiveLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double spacing = template.lineSpacing;

    switch (template.type) {
      case CanvasTemplateType.lined:
        // Horizontal ruled lines extending to infinity
        for (double y = spacing; y < height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);
        }
        // Left margin guide line (standard notebook style)
        final marginPaint = Paint()
          ..color = effectiveLineColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(56.0, 0), Offset(56.0, height), marginPaint);
        break;

      case CanvasTemplateType.grid:
        // Horizontal lines
        for (double y = spacing; y < height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);
        }
        // Vertical lines
        for (double x = spacing; x < width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, height), linePaint);
        }
        break;

      case CanvasTemplateType.dotted:
        final dotPaint = Paint()
          ..color = effectiveLineColor
          ..style = PaintingStyle.fill;
        for (double y = spacing; y < height; y += spacing) {
          for (double x = spacing; x < width; x += spacing) {
            canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
          }
        }
        break;

      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant InfiniteBackgroundPainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.width != width ||
        oldDelegate.height != height ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}

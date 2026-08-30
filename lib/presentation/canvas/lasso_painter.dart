import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// CustomPainter for Lasso selection loop and bounding box gizmo
class LassoPainter extends CustomPainter {
  final List<Offset> lassoPolygon;
  final Rect? boundingBox;

  const LassoPainter({
    required this.lassoPolygon,
    this.boundingBox,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Active Lasso Drawing Loop
    if (lassoPolygon.length >= 2) {
      final lassoPaint = Paint()
        ..color = AppColors.primaryBlue
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final Path lassoPath = Path()..moveTo(lassoPolygon.first.dx, lassoPolygon.first.dy);
      for (int i = 1; i < lassoPolygon.length; i++) {
        lassoPath.lineTo(lassoPolygon[i].dx, lassoPolygon[i].dy);
      }
      canvas.drawPath(lassoPath, lassoPaint);
    }

    // 2. Draw Selection Bounding Box Gizmo
    if (boundingBox != null) {
      final boxPaint = Paint()
        ..color = AppColors.primaryBlue
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final fillPaint = Paint()
        ..color = AppColors.primaryBlue.withOpacity(0.06)
        ..style = PaintingStyle.fill;

      canvas.drawRect(boundingBox!, fillPaint);
      canvas.drawRect(boundingBox!, boxPaint);

      // Draw Corner Handles
      final handlePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final handleBorder = Paint()
        ..color = AppColors.primaryBlue
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final corners = [
        boundingBox!.topLeft,
        boundingBox!.topRight,
        boundingBox!.bottomLeft,
        boundingBox!.bottomRight,
      ];

      for (final corner in corners) {
        canvas.drawCircle(corner, 6.0, handlePaint);
        canvas.drawCircle(corner, 6.0, handleBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LassoPainter oldDelegate) {
    return oldDelegate.lassoPolygon != lassoPolygon || oldDelegate.boundingBox != boundingBox;
  }
}

import '../../domain/models/note_document.dart';
import '../../core/math/bezier_spline.dart';

/// Pure SVG Vector Path Exporter for Vector Strokes
class SvgExporter {
  static String exportToSvg(NoteDocument doc, {double width = 820.0, double? height}) {
    final docHeight = height ?? doc.metadata.totalHeight;
    final StringBuffer sb = StringBuffer();

    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $docHeight" width="$width" height="$docHeight">');
    sb.writeln('  <rect width="100%" height="100%" fill="#FCFCFD"/>');

    for (final stroke in doc.strokes) {
      if (stroke.points.isEmpty) continue;

      final hexColor = '#${stroke.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      final opacity = stroke.opacity;

      if (stroke.points.length == 1) {
        final p = stroke.points.first;
        final r = stroke.baseWidth / 2.0;
        sb.writeln('  <circle cx="${p.x}" cy="${p.y}" r="$r" fill="$hexColor" fill-opacity="$opacity"/>');
      } else {
        final segments = BezierSplineCalculator.fitSpline(stroke.points, stroke.baseWidth);
        if (segments.isEmpty) continue;

        sb.write('  <path d="M ${segments.first.p0.dx} ${segments.first.p0.dy} ');
        for (final seg in segments) {
          sb.write('C ${seg.c1.dx} ${seg.c1.dy}, ${seg.c2.dx} ${seg.c2.dy}, ${seg.p1.dx} ${seg.p1.dy} ');
        }
        sb.writeln('" fill="none" stroke="$hexColor" stroke-width="${stroke.baseWidth}" stroke-linecap="round" stroke-linejoin="round" stroke-opacity="$opacity"/>');
      }
    }

    sb.writeln('</svg>');
    return sb.toString();
  }
}

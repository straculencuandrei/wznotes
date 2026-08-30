import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennotes/core/constants/app_colors.dart';
import 'package:opennotes/core/math/bezier_spline.dart';
import 'package:opennotes/core/math/pressure_filter.dart';
import 'package:opennotes/core/math/shape_recognizer.dart';
import 'package:opennotes/core/math/polygon_utils.dart';
import 'package:opennotes/domain/models/stroke_point.dart';
import 'package:opennotes/domain/models/vector_stroke.dart';
import 'package:opennotes/domain/models/pen_tool.dart';
import 'package:opennotes/domain/models/text_block.dart';
import 'package:opennotes/domain/models/note_document.dart';
import 'package:opennotes/domain/serialization/stroke_binary_codec.dart';
import 'package:opennotes/domain/serialization/note_json_codec.dart';
import 'package:opennotes/domain/serialization/note_archive_manager.dart';
import 'package:opennotes/infrastructure/export/markdown_exporter.dart';
import 'package:opennotes/infrastructure/export/svg_exporter.dart';

void main() {
  group('1. Binary & JSON Serialization Tests', () {
    test('Packed Binary Codec (strokes.bin) lossless round-trip', () {
      final List<VectorStroke> originalStrokes = [
        VectorStroke(
          id: 'test_stroke_1',
          toolType: PenType.calligraphy,
          color: const Color(0xFF2563EB),
          baseWidth: 3.5,
          opacity: 0.9,
          blendMode: BlendMode.srcOver,
          audioTimecodeMs: 1250,
          points: [
            const StrokePoint(x: 10.5, y: 20.25, pressure: 0.42, timestampMs: 1250, tilt: 0.1, orientation: 1.2),
            const StrokePoint(x: 15.0, y: 28.75, pressure: 0.88, timestampMs: 1266, tilt: 0.15, orientation: 1.25),
            const StrokePoint(x: 22.3, y: 35.10, pressure: 0.65, timestampMs: 1282, tilt: 0.2, orientation: 1.3),
          ],
        ),
      ];

      // Encode to binary byte buffer
      final bytes = StrokeBinaryCodec.encode(originalStrokes);
      expect(bytes.isNotEmpty, true);

      // Decode back from binary
      final decodedStrokes = StrokeBinaryCodec.decode(bytes);
      expect(decodedStrokes.length, 1);

      final stroke = decodedStrokes.first;
      expect(stroke.id, 'test_stroke_1');
      expect(stroke.toolType, PenType.calligraphy);
      expect(stroke.audioTimecodeMs, 1250);
      expect(stroke.points.length, 3);

      // Coordinate precision within float32 tolerance
      expect((stroke.points[0].x - 10.5).abs() < 0.01, true);
      expect((stroke.points[0].y - 20.25).abs() < 0.01, true);
      expect((stroke.points[0].pressure - 0.42).abs() < 0.01, true);
    });

    test('.note PKZip Archive packaging and extraction round-trip', () {
      final doc = NoteDocument.initial(title: 'Infinite Raft Consensus Notes');
      doc.blocks.add(const TextBlock(
        id: 'blk_test',
        type: TextBlockType.heading2,
        rawText: 'Leader Election Protocol',
      ));

      // Package to .note ZIP
      final zipBytes = NoteArchiveManager.packageNoteToZip(doc);
      expect(zipBytes.isNotEmpty, true);

      // Extract from .note ZIP
      final extractedDoc = NoteArchiveManager.extractNoteFromZip(zipBytes);
      expect(extractedDoc.metadata.title, 'Infinite Raft Consensus Notes');
      expect(extractedDoc.blocks.any((b) => b.rawText == 'Leader Election Protocol'), true);
    });
  });

  group('2. Math & Inking Engine Tests', () {
    test('Catmull-Rom to Cubic Bézier curve generation', () {
      final points = [
        const StrokePoint(x: 0, y: 0, pressure: 0.5, timestampMs: 0),
        const StrokePoint(x: 50, y: 100, pressure: 0.7, timestampMs: 16),
        const StrokePoint(x: 100, y: 50, pressure: 0.6, timestampMs: 32),
        const StrokePoint(x: 150, y: 150, pressure: 0.8, timestampMs: 48),
      ];

      final segments = BezierSplineCalculator.fitSpline(points, 3.0);
      expect(segments.length, 3);

      // Test point evaluation along the curve
      final midPoint = segments[0].pointAt(0.5);
      expect(midPoint.dx > 0 && midPoint.dx < 50, true);

      // Test normal vector computation
      final normal = segments[0].normalAt(0.5);
      final normalLen = sqrt(normal.dx * normal.dx + normal.dy * normal.dy);
      expect((normalLen - 1.0).abs() < 0.001, true);
    });

    test('Stylus low-pass EMA filter smooths raw pressure', () {
      final filter = StylusPressureFilter(alpha: 0.35);

      final p1 = filter.filter(position: const Offset(10, 10), rawPressure: 1.0, timestampMs: 0);
      final p2 = filter.filter(position: const Offset(20, 20), rawPressure: 0.2, timestampMs: 16);

      // Second filtered sample should be smoothly blended: 0.35 * 0.2 + 0.65 * 1.0 = 0.72
      expect((p2 - 0.72).abs() < 0.05, true);
    });

    test('Shape Recognizer snaps closed loop to circle', () {
      // Generate circular points
      final List<StrokePoint> circlePoints = [];
      const double radius = 50.0;
      const Offset center = Offset(100, 100);

      for (int i = 0; i < 20; i++) {
        final double angle = (i / 19) * 2 * pi;
        circlePoints.add(StrokePoint(
          x: center.dx + radius * cos(angle),
          y: center.dy + radius * sin(angle),
          pressure: 0.5,
          timestampMs: i * 16,
        ));
      }

      final result = ShapeRecognizer.recognize(circlePoints);
      expect(result.type, SnappedShapeType.circle);
      expect(result.isRecognized, true);
    });

    test('Jordan curve ray-casting algorithm for Lasso selection', () {
      final polygon = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];

      expect(PolygonUtils.isPointInsidePolygon(const Offset(50, 50), polygon), true);
      expect(PolygonUtils.isPointInsidePolygon(const Offset(150, 50), polygon), false);
    });
  });

  group('3. Export Pipeline Tests', () {
    test('Markdown exporter outputs structured blocks correctly', () {
      final doc = NoteDocument.initial(title: 'Quantum Physics');
      doc.blocks.add(const TextBlock(
        id: 'h1',
        type: TextBlockType.heading1,
        rawText: 'Introduction to Quantum Mechanics',
      ));
      final md = MarkdownExporter.exportToMarkdown(doc);

      expect(md.contains('# Quantum Physics'), true);
      expect(md.contains('# Introduction to Quantum Mechanics'), true);
    });

    test('SVG exporter produces valid SVG XML header and path tags', () {
      final doc = NoteDocument.initial(title: 'Vector Art');
      doc.strokes.add(VectorStroke(
        id: 's1',
        toolType: PenType.ballpoint,
        color: AppColors.primaryBlue,
        baseWidth: 3.0,
        points: [
          const StrokePoint(x: 10, y: 10, pressure: 0.5, timestampMs: 0),
          const StrokePoint(x: 40, y: 80, pressure: 0.7, timestampMs: 20),
        ],
      ));

      final svg = SvgExporter.exportToSvg(doc);
      expect(svg.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), true);
      expect(svg.contains('<svg'), true);
      expect(svg.contains('<path'), true);
    });
  });
}
